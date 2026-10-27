import AppKit
import os

/// Floating borderless window at the cursor that shows the radial menu.
@MainActor
final class WheelPanel: NSPanel {
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
        // Hiding waits while promised files arrive; afterwards the result stays visible a moment.
        wheelView.onBusyEnded = { [weak self] failed in self?.hideSoon(after: failed ? 2.5 : 0.4) }
    }

    /// `onPick` gets the index of the dropped-on item; `outer` is true when the outer ("replace") ring of the split wheel was chosen.
    func show(mode: WheelMode, items: [String], split: Bool, at point: NSPoint,
              onPick: @escaping (_ index: Int, _ urls: [URL], _ outer: Bool) -> Void) {
        hideWork?.cancel()
        let center = isVisible ? NSPoint(x: frame.midX, y: frame.midY) : point
        wheelView.onPick = onPick
        wheelView.configure(mode: mode, items: items, split: split)
        // Window only as large as the wheel so it doesn't cover other drop targets.
        let side = wheelView.diameter + 8
        var rect = NSRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
        // Keep the whole wheel on the screen that contains the cursor.
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(center, $0.frame, false) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            rect.origin.x = min(max(rect.minX, visible.minX), visible.maxX - side)
            rect.origin.y = min(max(rect.minY, visible.minY), visible.maxY - side)
        }
        setFrame(rect, display: true)
        orderFrontRegardless()
    }

    /// Slightly delayed so the confirmation after dropping stays visible.
    /// Doesn't hide while the wheel is receiving promised files; it calls this again when done.
    func hideSoon(after delay: TimeInterval = 0.4) {
        guard isVisible else { return }
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.wheelView.isBusy else { return }
            self.orderOut(nil)
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}

/// Draws the wheel segments and accepts dropped files.
final class WheelView: NSView {
    var onPick: ((_ index: Int, _ urls: [URL], _ outer: Bool) -> Void)?
    /// True while files promised by the drag source (Mail, Photos, Safari) are being received.
    private(set) var isBusy = false
    /// Called when receiving promised files has finished; `failed` if it didn't work.
    var onBusyEnded: ((_ failed: Bool) -> Void)?

    private static let logger = Logger(subsystem: "app.droplime.Droplime", category: "WheelView")

    struct Hit: Equatable {
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
    /// Room for the wheel plus the popped-out segment and its shadow.
    var diameter: CGFloat { (outerRadius + Self.popOffset + 14) * 2 }

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType(rawValue: $0) })
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(mode: WheelMode, items: [String], split: Bool) {
        self.mode = mode
        self.items = items
        self.split = split && !items.isEmpty
        highlighted = nil
        centerText = items.isEmpty ? L.nothingPossible : mode.title
        needsDisplay = true
    }

    /// Highlights a segment without an actual drag, for preview images (scripts/make-screenshots).
    func highlight(_ index: Int, outer: Bool = false) {
        highlighted = Hit(index: index, outer: outer)
        needsDisplay = true
    }

    private var center: NSPoint { NSPoint(x: bounds.midX, y: bounds.midY) }
    private var step: CGFloat { 360 / CGFloat(max(items.count, 1)) }

    /// Center angle of segment i in degrees; segment 0 at the top, then clockwise.
    private func angle(of i: Int) -> CGFloat { 90 - CGFloat(i) * step }

    func hit(at point: NSPoint) -> Hit? {
        let dx = point.x - center.x, dy = point.y - center.y
        let distance = hypot(dx, dy)
        guard !items.isEmpty, distance >= innerRadius, distance <= outerRadius else { return nil }
        let theta = atan2(dy, dx) * 180 / .pi
        var d = (90 - theta).truncatingRemainder(dividingBy: 360)
        if d < 0 { d += 360 }
        return Hit(index: Int((d + step / 2) / step) % items.count, outer: distance > middleRadius)
    }

    // MARK: - Drawing

    private static let lime = NSColor(red: 0.69, green: 0.86, blue: 0.27, alpha: 1)
    private static let amber = NSColor(red: 0.98, green: 0.74, blue: 0.27, alpha: 1)
    private static let segment = NSColor(white: 0.13, alpha: 0.94)
    private static let replaceSegment = NSColor(red: 0.2, green: 0.17, blue: 0.12, alpha: 0.94)
    private static let border = NSColor(white: 1, alpha: 0.08)

    /// Width of the gap between segments and between the two rings.
    private let gapWidth: CGFloat = 6
    private let cornerRadius: CGFloat = 9
    /// How far the highlighted segment pops out, like the popped segment in the app icon.
    private static let popOffset: CGFloat = 8

    /// Segment between radii r1 and r2 with rounded corners and constant-width gaps.
    /// Built from a shape inset by the corner radius, then grown back by a round-joined stroke.
    private func segmentPath(_ i: Int, from r1: CGFloat, to r2: CGFloat) -> NSBezierPath {
        let inner = r1 + cornerRadius, outer = r2 - cornerRadius
        let path = NSBezierPath()
        if items.count == 1 {
            path.appendOval(in: NSRect(x: center.x - outer, y: center.y - outer, width: outer * 2, height: outer * 2))
            // Hole drawn in the opposite direction so the non-zero rule leaves it empty.
            path.append(NSBezierPath(ovalIn: NSRect(x: center.x - inner, y: center.y - inner,
                                                    width: inner * 2, height: inner * 2)).reversed)
        } else {
            let d = gapWidth / 2 + cornerRadius
            let mid = angle(of: i) * .pi / 180, half = step / 2 * .pi / 180
            // Point on the edge line offset by d towards the segment's middle, at the given radius.
            func edge(_ edgeAngle: CGFloat, towardsMiddle sign: CGFloat, radius: CGFloat) -> NSPoint {
                let t = sqrt(max(radius * radius - d * d, 0))
                let normal = edgeAngle + sign * .pi / 2
                return NSPoint(x: center.x + cos(edgeAngle) * t + cos(normal) * d,
                               y: center.y + sin(edgeAngle) * t + sin(normal) * d)
            }
            func degrees(_ p: NSPoint) -> CGFloat { atan2(p.y - center.y, p.x - center.x) * 180 / .pi }
            let outerRight = edge(mid - half, towardsMiddle: 1, radius: outer)
            let outerLeft = edge(mid + half, towardsMiddle: -1, radius: outer)
            let innerLeft = edge(mid + half, towardsMiddle: -1, radius: inner)
            let innerRight = edge(mid - half, towardsMiddle: 1, radius: inner)
            path.move(to: innerRight)
            path.line(to: outerRight)
            path.appendArc(withCenter: center, radius: outer, startAngle: degrees(outerRight), endAngle: degrees(outerLeft))
            path.line(to: innerLeft)
            path.appendArc(withCenter: center, radius: inner, startAngle: degrees(innerLeft), endAngle: degrees(innerRight),
                           clockwise: true)
            path.close()
        }
        let core = path.cgPath
        let grown = core.copy(strokingWithWidth: cornerRadius * 2, lineCap: .round, lineJoin: .round, miterLimit: 10)
        // Non-zero rule: the stroke outline overlaps itself, which even-odd would punch holes into.
        return NSBezierPath(cgPath: core.union(grown, using: .winding))
    }

    private func point(at radius: CGFloat, angle a: CGFloat) -> NSPoint {
        let rad = a * .pi / 180
        return NSPoint(x: center.x + cos(rad) * radius, y: center.y + sin(rad) * radius)
    }

    /// Offset for a popped-out segment, along its middle direction.
    private func popOffset(for i: Int) -> NSPoint {
        let rad = angle(of: i) * .pi / 180
        return NSPoint(x: cos(rad) * Self.popOffset, y: sin(rad) * Self.popOffset)
    }

    private func drawSegment(_ path: NSBezierPath, fill: NSColor, highlighted: Bool) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(highlighted ? 0.5 : 0.3)
        shadow.shadowBlurRadius = highlighted ? 14 : 8
        shadow.shadowOffset = NSSize(width: 0, height: -3)
        shadow.set()
        fill.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
        if !highlighted {
            Self.border.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let ringGap = split ? gapWidth / 2 : 0
        // Highlighted segment last, so its shadow lies on top of its neighbours.
        let order = items.indices.filter { $0 != highlighted?.index } + (highlighted.map { [$0.index] } ?? [])
        for i in order {
            let item = items[i]
            let a = angle(of: i)

            let innerHit = highlighted == Hit(index: i, outer: false)
            let innerPath = segmentPath(i, from: innerRadius, to: middleRadius - ringGap)
            let innerShift = innerHit ? popOffset(for: i) : .zero
            innerPath.transform(using: AffineTransform(translationByX: innerShift.x, byY: innerShift.y))
            drawSegment(innerPath, fill: innerHit ? Self.lime : Self.segment, highlighted: innerHit)
            var labelPoint = point(at: (innerRadius + middleRadius) / 2, angle: a)
            labelPoint.x += innerShift.x; labelPoint.y += innerShift.y
            let innerColor: NSColor = innerHit ? .black : .white
            if split {
                drawText(item, at: NSPoint(x: labelPoint.x, y: labelPoint.y + 6), size: 13, weight: .semibold, color: innerColor)
                drawText(L.wheelKeep, at: NSPoint(x: labelPoint.x, y: labelPoint.y - 9), size: 9, weight: .medium,
                         color: innerColor.withAlphaComponent(0.6))
            } else {
                drawText(item, at: labelPoint, size: 13, weight: .semibold, color: innerColor)
            }

            if split {
                let outerHit = highlighted == Hit(index: i, outer: true)
                let outerPath = segmentPath(i, from: middleRadius + ringGap, to: outerRadius)
                let outerShift = outerHit ? popOffset(for: i) : .zero
                outerPath.transform(using: AffineTransform(translationByX: outerShift.x, byY: outerShift.y))
                drawSegment(outerPath, fill: outerHit ? Self.amber : Self.replaceSegment, highlighted: outerHit)
                var p = point(at: (middleRadius + outerRadius) / 2, angle: a)
                p.x += outerShift.x; p.y += outerShift.y
                let color: NSColor = outerHit ? .black : Self.amber
                drawSymbol("arrow.triangle.2.circlepath", at: NSPoint(x: p.x, y: p.y + 7), color: color)
                drawText(L.wheelReplace, at: NSPoint(x: p.x, y: p.y - 9), size: 9, weight: .semibold, color: color)
            }
        }

        let hub = NSBezierPath(ovalIn: NSRect(x: center.x - innerRadius + 4, y: center.y - innerRadius + 4,
                                              width: (innerRadius - 4) * 2, height: (innerRadius - 4) * 2))
        drawSegment(hub, fill: NSColor(white: 0.09, alpha: 0.96), highlighted: false)
        drawText(centerText, at: center, size: 10, weight: .semibold, color: .white)
    }

    private func drawText(_ text: String, at point: NSPoint, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
        let s = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
        ])
        let textSize = s.size()
        s.draw(at: NSPoint(x: point.x - textSize.width / 2, y: point.y - textSize.height / 2))
    }

    private func drawSymbol(_ name: String, at point: NSPoint, color: NSColor) {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            .applying(.init(paletteColors: [color]))
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }
        image.draw(in: NSRect(x: point.x - image.size.width / 2, y: point.y - image.size.height / 2,
                              width: image.size.width, height: image.size.height))
    }

    // MARK: - Drop target

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
        guard let target = hit(at: convert(sender.draggingLocation, from: nil)) else { return false }
        let pasteboard = sender.draggingPasteboard
        let item = items[target.index], pick = pick(at: target)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            showCenter("✓ \(item)")
            pick(urls)
            return true
        }
        // File promises: let the source write the files into Downloads, then continue as with a normal drop.
        guard let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver],
              !receivers.isEmpty,
              let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        else { return false }
        isBusy = true
        showCenter(L.wheelReceiving)
        receive(receivers, into: downloads) { [weak self] urls, errors in
            guard let self else { return }
            self.isBusy = false
            if errors.isEmpty, !urls.isEmpty {
                self.showCenter("✓ \(item)")
                pick(urls)
                self.onBusyEnded?(false)
            } else {
                for error in errors { Self.logger.error("Receiving a promised file failed: \(error.localizedDescription)") }
                self.showCenter("✗ \(L.wheelReceiveFailed)")
                self.onBusyEnded?(true)
            }
        }
        return true
    }

    /// Binds the dropped-on segment now, so files that arrive later still go to it even if another wheel was shown meanwhile.
    func pick(at target: Hit) -> ([URL]) -> Void {
        let onPick = onPick
        return { urls in onPick?(target.index, urls, target.outer) }
    }

    private func showCenter(_ text: String) {
        centerText = text
        highlighted = nil
        needsDisplay = true
    }

    /// Results of one receive; only used on the main thread. Calls `completion` once, when every file
    /// has arrived or failed or when timed out, whichever comes first; anything after that is ignored.
    final class PromiseReceipt {
        private let expected: Int
        private let completion: ([URL], [Error]) -> Void
        private var urls: [URL] = []
        private var errors: [Error] = []
        private(set) var isFinished = false

        init(expected: Int, completion: @escaping ([URL], [Error]) -> Void) {
            self.expected = expected
            self.completion = completion
        }

        func add(_ url: URL, error: Error?) {
            guard !isFinished else { return }
            if let error { errors.append(error) } else { urls.append(url) }
            if urls.count + errors.count >= expected { finish(errors: errors) }
        }

        func timeOut(with error: Error) {
            guard !isFinished else { return }
            finish(errors: errors + [error])
        }

        private func finish(errors: [Error]) {
            isFinished = true
            completion(urls, errors)
        }
    }

    /// Longest wait for promised files, so the wheel can never stay busy forever.
    private static let receiveTimeout: TimeInterval = 60

    /// Receives all promised files and calls `completion` on the main thread once every file has arrived or failed,
    /// or with an error after `receiveTimeout`.
    private func receive(_ receivers: [NSFilePromiseReceiver], into folder: URL,
                         completion: @escaping ([URL], [Error]) -> Void) {
        // The reader runs once per promised file.
        let expected = receivers.reduce(0) { sum, receiver in
            sum + (receiver.fileNames.isEmpty ? max(receiver.fileTypes.count, 1) : receiver.fileNames.count)
        }
        let receipt = PromiseReceipt(expected: expected, completion: completion)
        // Reading can block this queue as long as the source takes (e.g. an iCloud download),
        // so results and the timeout are handled on the main thread instead.
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        for receiver in receivers {
            receiver.receivePromisedFiles(atDestination: folder, options: [:], operationQueue: queue) { url, error in
                DispatchQueue.main.async { receipt.add(url, error: error) }
            }
        }
        let timeoutError = ConversionError(message: L.wheelReceiveFailed)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.receiveTimeout) { receipt.timeOut(with: timeoutError) }
    }
}
