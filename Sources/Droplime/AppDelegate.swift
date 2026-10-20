import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let watcher = DragWatcher()
    private let wheel = WheelPanel()
    private let settings = Settings.shared
    private var service: ConversionService!
    private var tools: [(name: String, found: Bool, install: String)] = []
    private var settingsWindow: NSWindow?
    /// Zielformate für die Dateien, die gerade gezogen werden.
    private var currentTargets: [Format] = []
    private static let maxWheelItems = 10

    func applicationDidFinishLaunching(_ notification: Notification) {
        let ffmpeg = FFmpegConverter()
        let libreOffice = LibreOfficeConverter()
        let pandoc = PandocConverter()
        // Reihenfolge = Vorrang bei gleichen Zielformaten.
        let optional: [Converter?] = [libreOffice, pandoc]
        service = ConversionService(converters:
            [ImageConverter(), PDFConverter()] + optional.compactMap { $0 }
            + [DocumentConverter(), MediaConverter()] + [ffmpeg].compactMap { $0 })
        tools = [("FFmpeg", ffmpeg != nil, "brew install ffmpeg"),
                 ("LibreOffice", libreOffice != nil, "brew install --cask libreoffice"),
                 ("Pandoc", pandoc != nil, "brew install pandoc")]

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = LimeIcon.menuBarImage()
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Einstellungen …", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Droplime beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        watcher.onModifierTap = { [weak self] mode in
            self?.showWheel(mode)
        }
        watcher.onMouseUp = { [weak self] in
            self?.wheel.hideSoon()
        }
        wheel.onPick = { [weak self] mode, item, urls, outer in
            self?.handlePick(mode: mode, item: item, urls: urls, outer: outer)
        }
        watcher.start()
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings, available: service.producibleFormats, tools: tools)
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Droplime Einstellungen"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func showWheel(_ mode: WheelMode) {
        var items = mode.items
        if mode == .convert {
            let urls = NSPasteboard(name: .drag).readObjects(
                forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
            currentTargets = Array(service.targets(for: urls).filter(settings.isEnabled).prefix(Self.maxWheelItems))
            items = currentTargets.map(\.label)
        }
        let split = mode == .convert && settings.afterConversion == .split
        wheel.show(mode: mode, items: items, split: split, at: NSEvent.mouseLocation)
    }

    private func handlePick(mode: WheelMode, item: String, urls: [URL], outer: Bool) {
        switch mode {
        case .convert:
            if let format = currentTargets.first(where: { $0.label == item }) { convert(urls, to: format, outer: outer) }
        case .actions:
            guard let action = FileAction.allCases.first(where: { $0.label == item }) else { return }
            // Erst nach dem Ende des Drags ausführen, damit Dialoge (z. B. Ordnerwahl) nicht mitten im Drag aufgehen.
            DispatchQueue.main.async { [weak self] in
                do {
                    if try action.perform(on: urls), action != .airDrop, action != .float {
                        NSSound(named: "Glass")?.play()
                    }
                } catch {
                    self?.showError("Aktion fehlgeschlagen", error.localizedDescription)
                }
            }
        case .tools:
            print("[\(mode.title)] \(item) ← \(urls.map(\.lastPathComponent).joined(separator: ", ")) (noch nicht umgesetzt)")
        }
    }

    private func convert(_ urls: [URL], to format: Format, outer: Bool) {
        let replace = switch settings.afterConversion {
        case .keep: false
        case .replace: true
        case .split: outer
        }
        Task {
            let errors = await service.convert(urls, to: format, replaceOriginals: replace).errors
            if errors.isEmpty {
                print("✓ \(urls.count) Datei(en) → \(format.label)\(replace ? " (Original im Papierkorb)" : "")")
                NSSound(named: "Glass")?.play()
            } else {
                showError("Konvertierung fehlgeschlagen", errors.map(\.localizedDescription).joined(separator: "\n\n"))
            }
        }
    }

    private func showError(_ title: String, _ message: String) {
        print("✗ \(message)")
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        NSApp.activate()
        alert.runModal()
    }
}
