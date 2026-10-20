import AppKit
import QuickLookThumbnailing

/// Kleines, immer sichtbares Fenster mit einer Vorschau der Dateien.
/// Die Dateien lassen sich jederzeit wieder herausziehen – auch direkt ins Droplime-Rad.
@MainActor
final class FloatPanel: NSPanel, NSWindowDelegate {
    /// Offene Fenster festhalten, bis sie geschlossen werden.
    private static var open: Set<FloatPanel> = []

    static func show(_ urls: [URL]) {
        let panel = FloatPanel(urls: urls)
        open.insert(panel)
        // Neben den Mauszeiger, versetzt, damit mehrere Fenster nicht exakt übereinander liegen.
        let mouse = NSEvent.mouseLocation
        let offset = CGFloat(open.count - 1) * 24
        panel.setFrameTopLeftPoint(NSPoint(x: mouse.x + 40 + offset, y: mouse.y + 80 - offset))
        panel.orderFrontRegardless()
    }

    private init(urls: [URL]) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 168, height: 176),
                   styleMask: [.titled, .closable, .utilityWindow, .hudWindow, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        title = urls.count == 1 ? urls[0].lastPathComponent : L.floatItems(urls.count)
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        delegate = self
        contentView = FloatView(urls: urls)
    }

    func windowWillClose(_ notification: Notification) {
        Self.open.remove(self)
    }
}

/// Zeigt die Vorschau und dient als Ziehquelle für die Dateien.
private final class FloatView: NSView, NSDraggingSource {
    private let urls: [URL]
    private var thumbnail: NSImage

    init(urls: [URL]) {
        self.urls = urls
        thumbnail = NSWorkspace.shared.icon(forFile: urls[0].path)
        super.init(frame: .zero)
        toolTip = L.floatTooltip
        let request = QLThumbnailGenerator.Request(fileAt: urls[0], size: CGSize(width: 136, height: 136),
                                                   scale: NSScreen.main?.backingScaleFactor ?? 2,
                                                   representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] rep, _ in
            guard let image = rep?.nsImage else { return }
            DispatchQueue.main.async {
                self?.thumbnail = image
                self?.needsDisplay = true
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var imageRect: NSRect {
        let side = min(bounds.width, bounds.height) - 24
        return NSRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2 + (urls.count > 1 ? 6 : 0),
                      width: side, height: side)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Seitenverhältnis erhalten
        let size = thumbnail.size, box = imageRect
        let scale = min(box.width / max(size.width, 1), box.height / max(size.height, 1))
        let drawn = NSSize(width: size.width * scale, height: size.height * scale)
        thumbnail.draw(in: NSRect(x: box.midX - drawn.width / 2, y: box.midY - drawn.height / 2,
                                  width: drawn.width, height: drawn.height))
        if urls.count > 1 {
            let label = NSAttributedString(string: L.floatMore(urls.count - 1), attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.secondaryLabelColor,
            ])
            label.draw(at: NSPoint(x: bounds.midX - label.size().width / 2, y: 4))
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDragged(with event: NSEvent) {
        let items = urls.enumerated().map { index, url in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let offset = CGFloat(index) * 6
            item.setDraggingFrame(imageRect.offsetBy(dx: offset, dy: -offset), contents: thumbnail)
            return item
        }
        beginDraggingSession(with: items, event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move, .link, .generic] : .copy
    }
}
