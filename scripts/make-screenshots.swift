// Erzeugt die Bilder in docs/images für die README. Aufruf über scripts/make-screenshots.sh
import AppKit
import SwiftUI
import UniformTypeIdentifiers

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func save(_ view: NSView, _ name: String) {
    view.appearance = NSAppearance(named: .darkAqua)
    view.layoutSubtreeIfNeeded()
    let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: rep)
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name))
}

/// Hintergrund wie ein Schreibtisch, darauf das Rad, eine gezogene Datei mit Mauszeiger und die gedrückte Taste.
final class Scene: NSView {
    let key: String, file: String
    init(size: CGFloat, key: String, file: String) {
        self.key = key; self.file = file
        super.init(frame: NSRect(x: 0, y: 0, width: size, height: size + 70))
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        NSGradient(starting: NSColor(red: 0.2, green: 0.25, blue: 0.2, alpha: 1),
                   ending: NSColor(red: 0.09, green: 0.11, blue: 0.09, alpha: 1))!.draw(in: bounds, angle: -90)
    }

    /// Wird nach dem Rad gezeichnet (als eigene Ebene darüber).
    final class Overlay: NSView {
        let key: String, file: String, cursorPoint: NSPoint
        init(frame: NSRect, key: String, file: String, cursorPoint: NSPoint) {
            self.key = key; self.file = file; self.cursorPoint = cursorPoint; super.init(frame: frame)
        }
        required init?(coder: NSCoder) { fatalError() }
        override func draw(_ dirtyRect: NSRect) {
            let c = cursorPoint
            // Gezogene Datei, halb transparent wie beim echten Drag
            let icon = NSWorkspace.shared.icon(for: UTType(filenameExtension: file) ?? .data)
            icon.draw(in: NSRect(x: c.x + 6, y: c.y - 58, width: 52, height: 52), from: .zero, operation: .sourceOver, fraction: 0.85)
            // Mauszeiger
            let cursor = NSCursor.arrow.image
            cursor.draw(in: NSRect(x: c.x, y: c.y - cursor.size.height, width: cursor.size.width, height: cursor.size.height))
            // Taste
            let label = NSAttributedString(string: key, attributes: [
                .font: NSFont.systemFont(ofSize: 20, weight: .semibold), .foregroundColor: NSColor.black,
            ])
            let size = label.size()
            let pill = NSRect(x: bounds.midX - size.width / 2 - 18, y: 16, width: size.width + 36, height: 40)
            NSColor(red: 0.8, green: 0.93, blue: 0.45, alpha: 1).setFill()
            NSBezierPath(roundedRect: pill, xRadius: 10, yRadius: 10).fill()
            label.draw(at: NSPoint(x: pill.midX - size.width / 2, y: pill.midY - size.height / 2))
        }
    }
}

func wheelScene(_ name: String, mode: WheelMode, items: [String], split: Bool = false,
                highlight: Int, outer: Bool = false, key: String, file: String) {
    let wheel = WheelView(frame: .zero)
    wheel.configure(mode: mode, items: items, split: split)
    wheel.highlight(highlight, outer: outer)
    let side = wheel.diameter + 60
    let scene = Scene(size: side, key: key, file: file)
    wheel.frame = NSRect(x: 30, y: 70 + 30, width: wheel.diameter, height: wheel.diameter)
    scene.addSubview(wheel)
    // Mauszeiger auf dem hervorgehobenen Feld, leicht neben der Beschriftung.
    let angle = (90 - CGFloat(highlight) * 360 / CGFloat(items.count)) * .pi / 180
    let radius: CGFloat = split ? (outer ? 168 : 100) : 118
    let center = NSPoint(x: wheel.frame.midX, y: wheel.frame.midY)
    let cursorPoint = NSPoint(x: center.x + cos(angle) * radius + 14, y: center.y + sin(angle) * radius - 6)
    scene.addSubview(Scene.Overlay(frame: scene.bounds, key: key, file: file, cursorPoint: cursorPoint))
    save(scene, name)
}

MainActor.assumeIsolated {
    _ = NSApplication.shared
    wheelScene("wheel-convert.png", mode: .convert, items: ["JPG", "HEIC", "TIFF", "GIF", "BMP", "PDF"],
               highlight: 0, key: "⇧ Shift", file: "png")
    wheelScene("wheel-split.png", mode: .convert, items: ["PDF", "RTF", "HTML", "TXT", "ODT"], split: true,
               highlight: 0, outer: true, key: "⇧ Shift", file: "docx")
    wheelScene("wheel-tools.png", mode: .tools, items: ["Zusammenfügen", "ZIP"],
               highlight: 0, key: "⌘ Cmd", file: "pdf")
    wheelScene("wheel-actions.png", mode: .actions, items: FileAction.allCases.map(\.label),
               highlight: 5, key: "⌃ Ctrl", file: "jpg")

    let available: Set<Format> = [.png, .jpg, .heic, .tiff, .gif, .bmp, .pdf, .docx, .odt, .rtf, .html, .txt,
                                  .mp4, .mov, .mkv, .webm, .mp3, .m4a, .wav, .aiff, .flac, .opus]
    let host = NSHostingView(rootView: SettingsView(settings: .shared, available: available,
        tools: [("FFmpeg", true, "brew install ffmpeg"), ("LibreOffice", false, "brew install --cask libreoffice"),
                ("Pandoc", false, "brew install pandoc")]))
    host.frame = NSRect(origin: .zero, size: host.fittingSize)
    let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = host
    save(host, "settings.png")
}
