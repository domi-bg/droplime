import AppKit

/// Schwebendes, randloses Fenster am Mauszeiger, das das Radialmenü zeigt.
@MainActor
final class WheelPanel: NSPanel {
    /// `outer` ist true, wenn im geteilten Rad der äußere Ring („ersetzen“) gewählt wurde.
    var onPick: ((_ mode: WheelMode, _ item: String, _ urls: [URL], _ outer: Bool) -> Void)? {
        get { wheelView.onPick }
        set { wheelView.onPick = newValue }
    }

    private let wheelView = WheelView(frame: .zero)
    private var hideWork: DispatchWorkItem?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .popUpMenu
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = wheelView
    }

    func show(mode: WheelMode, items: [String], split: Bool, at point: NSPoint) {
        hideWork?.cancel()
        let center = isVisible ? NSPoint(x: frame.midX, y: frame.midY) : point
        wheelView.configure(mode: mode, items: items, split: split)
        // Fenster nur so groß wie das Rad, damit es keine fremden Drop-Ziele verdeckt.
        let side = wheelView.diameter + 8
        setFrame(NSRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side), display: true)
        orderFrontRegardless()
    }

    /// Kurz verzögert, damit die Bestätigung nach dem Ablegen sichtbar bleibt.
    func hideSoon() {
        guard isVisible else { return }
        let work = DispatchWorkItem { [weak self] in self?.orderOut(nil) }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }
}

/// Zeichnet die Kreissektoren und nimmt Dateien per Drag & Drop an.
final class WheelView: NSView {
    var onPick: ((WheelMode, String, [URL], Bool) -> Void)?

    private struct Hit: Equatable {
        let index: Int
        let outer: Bool
    }

    private var mode: WheelMode = .convert
    private var items: [String] = []
    private var split = false
    private var highlighted: Hit?
    private var centerText = ""

    private let innerRadius: CGFloat = 48
    private var middleRadius: CGFloat { split ? 128 : 150 }
    private var outerRadius: CGFloat { split ? 190 : 150 }
    var diameter: CGFloat { outerRadius * 2 + 8 }

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(mode: WheelMode, items: [String], split: Bool) {
        self.mode = mode
        self.items = items
        self.split = split && !items.isEmpty
        highlighted = nil
        centerText = items.isEmpty ? "Nichts möglich" : mode.title
        needsDisplay = true
    }

    /// Hebt ein Feld hervor, ohne dass gezogen wird – für Vorschaubilder (scripts/make-screenshots).
    func highlight(_ index: Int, outer: Bool = false) {
        highlighted = Hit(index: index, outer: outer)
        needsDisplay = true
    }

    private var center: NSPoint { NSPoint(x: bounds.midX, y: bounds.midY) }
    private var step: CGFloat { 360 / CGFloat(max(items.count, 1)) }

    /// Mittelwinkel von Sektor i in Grad; Sektor 0 oben, dann im Uhrzeigersinn.
    private func angle(of i: Int) -> CGFloat { 90 - CGFloat(i) * step }

    private func hit(at point: NSPoint) -> Hit? {
        let dx = point.x - center.x, dy = point.y - center.y
        let distance = hypot(dx, dy)
        guard !items.isEmpty, distance >= innerRadius, distance <= outerRadius else { return nil }
        let theta = atan2(dy, dx) * 180 / .pi
        var d = (90 - theta).truncatingRemainder(dividingBy: 360)
        if d < 0 { d += 360 }
        return Hit(index: Int((d + step / 2) / step) % items.count, outer: distance > middleRadius)
    }

    // MARK: - Zeichnen

    private static let lime = NSColor(red: 0.66, green: 0.84, blue: 0.23, alpha: 1)
    private static let segment = NSColor(white: 0.12, alpha: 0.9)
    private static let replaceSegment = NSColor(red: 0.24, green: 0.11, blue: 0.11, alpha: 0.92)

    private func sectorPath(_ i: Int, from r1: CGFloat, to r2: CGFloat) -> NSBezierPath {
        let a = angle(of: i), gap: CGFloat = items.count > 1 ? 1.2 : 0
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: r2, startAngle: a + step / 2 - gap, endAngle: a - step / 2 + gap, clockwise: true)
        path.appendArc(withCenter: center, radius: r1, startAngle: a - step / 2 + gap, endAngle: a + step / 2 - gap, clockwise: false)
        path.close()
        return path
    }

    private func point(at radius: CGFloat, angle a: CGFloat) -> NSPoint {
        let rad = a * .pi / 180
        return NSPoint(x: center.x + cos(rad) * radius, y: center.y + sin(rad) * radius)
    }

    override func draw(_ dirtyRect: NSRect) {
        for (i, item) in items.enumerated() {
            let innerHit = highlighted == Hit(index: i, outer: false)
            (innerHit ? Self.lime : Self.segment).setFill()
            sectorPath(i, from: innerRadius, to: middleRadius).fill()
            drawText(item, at: point(at: (innerRadius + middleRadius) / 2, angle: angle(of: i)),
                     size: 13, color: innerHit ? .black : .white)

            if split {
                let outerHit = highlighted == Hit(index: i, outer: true)
                (outerHit ? NSColor.systemRed : Self.replaceSegment).setFill()
                sectorPath(i, from: middleRadius, to: outerRadius).fill()
                drawSymbol("trash", at: point(at: (middleRadius + outerRadius) / 2, angle: angle(of: i)))
            }
        }

        NSColor(white: 0.08, alpha: 0.94).setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - innerRadius + 3, y: center.y - innerRadius + 3,
                                    width: (innerRadius - 3) * 2, height: (innerRadius - 3) * 2)).fill()
        drawText(centerText, at: center, size: 10, color: .white)
    }

    private func drawText(_ text: String, at point: NSPoint, size: CGFloat, color: NSColor) {
        let s = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: color,
        ])
        let textSize = s.size()
        s.draw(at: NSPoint(x: point.x - textSize.width / 2, y: point.y - textSize.height / 2))
    }

    private func drawSymbol(_ name: String, at point: NSPoint) {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            .applying(.init(paletteColors: [.white.withAlphaComponent(0.85)]))
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }
        image.draw(in: NSRect(x: point.x - image.size.width / 2, y: point.y - image.size.height / 2,
                              width: image.size.width, height: image.size.height))
    }

    // MARK: - Drop-Ziel

    private func updateHighlight(_ sender: NSDraggingInfo) -> NSDragOperation {
        let current = hit(at: convert(sender.draggingLocation, from: nil))
        if current != highlighted {
            highlighted = current
            needsDisplay = true
        }
        return current == nil ? [] : .copy
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { updateHighlight(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { updateHighlight(sender) }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        highlighted = nil
        needsDisplay = true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let target = hit(at: convert(sender.draggingLocation, from: nil)),
              let urls = sender.draggingPasteboard.readObjects(
                  forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !urls.isEmpty
        else { return false }
        let item = items[target.index]
        centerText = "✓ \(item)"
        highlighted = nil
        needsDisplay = true
        onPick?(mode, item, urls, target.outer)
        return true
    }
}
