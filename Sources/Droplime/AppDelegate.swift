import AppKit
import Combine
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
    private var languageObserver: AnyCancellable?
    /// Target formats for the files currently being dragged.
    private var currentTargets: [Format] = []
    private let toolService = ToolService.standard()
    private let jobs = JobQueue()
    private var jobsObserver: AnyCancellable?
    /// Files being converted or waiting; drives the menu bar animation and the progress menu items.
    private var filesInProgress = 0
    private var progressItem: NSMenuItem?
    private var cancelItem: NSMenuItem?
    private var progressSeparator: NSMenuItem?
    private var animationTimer: Timer?
    private var animationFrame = 0
    private lazy var animationFrames = (0..<LimeIcon.segmentCount).map { LimeIcon.menuBarImage(popped: $0) }
    /// Tools for the files currently being dragged.
    private var currentTools: [Tool] = []
    private static let maxWheelItems = 10

    func applicationDidFinishLaunching(_ notification: Notification) {
        detectTools()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = LimeIcon.menuBarImage()
        buildMenu()
        // @Published fires before the change, so take the new values from the publisher.
        jobsObserver = jobs.$running.combineLatest(jobs.$pending).sink { [weak self] running, pending in
            self?.showProgress(files: running + pending)
        }
        // Switch language immediately: rebuild menu and window title (SwiftUI updates itself).
        languageObserver = settings.$language.dropFirst().receive(on: RunLoop.main).sink { [weak self] _ in
            self?.buildMenu()
            self?.settingsWindow?.title = L.settingsWindowTitle
        }

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

    /// Looks for the optional tools and builds the converters from what is installed.
    /// Runs at launch and whenever Settings opens, so newly installed tools need no restart.
    private func detectTools() {
        let ffmpeg = FFmpegConverter()
        let libreOffice = LibreOfficeConverter()
        let pandoc = PandocConverter()
        // Order = priority when several converters offer the same format.
        let optional: [Converter?] = [libreOffice, pandoc]
        service = ConversionService(converters:
            [ImageConverter(quality: { Settings.shared.lossyQuality }), PDFConverter()] + optional.compactMap { $0 }
            + [DocumentConverter(), MediaConverter()] + [ffmpeg].compactMap { $0 })
        tools = [("FFmpeg", ffmpeg != nil, "brew install ffmpeg"),
                 ("LibreOffice", libreOffice != nil, "brew install --cask libreoffice"),
                 ("Pandoc", pandoc != nil, "brew install pandoc")]
        let found = tools.map { "\($0.name) \($0.found ? "found" : "missing")" }.joined(separator: ", ")
        Log.tools.info("Optional tools: \(found, privacy: .public)")
    }

    private func buildMenu() {
        let menu = NSMenu()
        let progressItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        progressItem.isEnabled = false
        let cancelItem = NSMenuItem(title: L.menuCancel, action: #selector(cancelJobs), keyEquivalent: "")
        cancelItem.target = self
        let progressSeparator = NSMenuItem.separator()
        menu.autoenablesItems = false
        menu.addItem(progressItem)
        menu.addItem(cancelItem)
        menu.addItem(progressSeparator)
        (self.progressItem, self.cancelItem, self.progressSeparator) = (progressItem, cancelItem, progressSeparator)
        let settingsItem = NSMenuItem(title: L.menuSettings, action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let updateItem = NSMenuItem(title: L.menuCheckForUpdates, action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L.menuQuit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        showProgress(files: filesInProgress)
    }

    @objc private func cancelJobs() {
        jobs.cancelAll()
    }

    /// While files are being converted: animated icon, tooltip, progress and Cancel items in the menu.
    private func showProgress(files: Int) {
        filesInProgress = files
        let busy = files > 0
        progressItem?.title = busy ? L.menuConverting(files) : ""
        for item in [progressItem, cancelItem, progressSeparator] { item?.isHidden = !busy }
        statusItem.button?.toolTip = busy ? L.menuConverting(files) : nil
        if busy, animationTimer == nil {
            // Common modes, so the animation keeps running while the menu is open or an alert is shown.
            let timer = Timer(timeInterval: 1.0 / 8, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.advanceAnimation() }
            }
            RunLoop.main.add(timer, forMode: .common)
            animationTimer = timer
        } else if !busy, let timer = animationTimer {
            timer.invalidate()
            animationTimer = nil
            statusItem.button?.image = LimeIcon.menuBarImage()
        }
    }

    /// Moves the popped-out segment one step clockwise around the ring.
    private func advanceAnimation() {
        animationFrame = (animationFrame + 1) % animationFrames.count
        statusItem.button?.image = animationFrames[animationFrame]
    }

    /// Manual only: Droplime makes no network requests unless the user asks for this.
    @objc private func checkForUpdates() {
        Task { @MainActor in
            let alert = NSAlert()
            switch await UpdateChecker.check() {
            case .upToDate(let version):
                alert.messageText = L.updateUpToDate(version)
            case .available(let version, let url):
                alert.messageText = L.updateAvailable(version)
                alert.addButton(withTitle: L.updateDownload)
                alert.addButton(withTitle: L.updateLater)
                NSApp.activate()
                if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(url) }
                return
            case .failed(let message):
                alert.messageText = L.updateCheckFailed
                alert.informativeText = message
            }
            NSApp.activate()
            alert.runModal()
        }
    }

    @objc private func showSettings() {
        detectTools()
        let view = SettingsView(settings: settings, available: service.producibleFormats, tools: tools)
        if let window = settingsWindow {
            window.contentViewController = NSHostingController(rootView: view)
        } else {
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = L.settingsWindowTitle
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
        let pasteboard = NSPasteboard(name: .drag)
        let urls = pasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        // Without file URLs the drag may carry file promises (Mail, Photos, Safari), which only know their types.
        let promises = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver] ?? []
        let types = urls.isEmpty
            ? ConversionService.types(identifiers: promises.flatMap(\.fileTypes))
            : ConversionService.types(of: urls)
        switch mode {
        case .convert:
            currentTargets = Array(service.targets(forTypes: types).filter(settings.isEnabled).prefix(Self.maxWheelItems))
            items = currentTargets.map(\.label)
        case .tools:
            currentTools = Array(toolService.tools(forTypes: types).prefix(Self.maxWheelItems))
            items = currentTools.map(\.label)
        case .actions:
            break
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
            // Run after the drag has ended so dialogs (e.g. the folder picker) don't open mid-drag.
            DispatchQueue.main.async { [weak self] in
                do {
                    if try action.perform(on: urls), action != .airDrop, action != .float {
                        self?.playSuccessSound()
                    }
                } catch {
                    self?.showError(L.actionFailed, error.localizedDescription)
                }
            }
        case .tools:
            guard let tool = currentTools.first(where: { $0.label == item }) else { return }
            jobs.enqueue(Job(title: "\(tool.label): \(Self.fileCount(urls.count))", fileCount: urls.count) { [weak self] in
                do {
                    let outputs = try await tool.run(urls)
                    let names = outputs.map(\.lastPathComponent).joined(separator: ", ")
                    Log.jobs.info("\(tool.label, privacy: .public) created \(names, privacy: .public)")
                    self?.playSuccessSound()
                } catch {
                    if error is CancellationError || Task.isCancelled { throw CancellationError() }
                    self?.showErrorLater(L.toolFailed(tool.label), error.localizedDescription)
                }
            })
        }
    }

    private func convert(_ urls: [URL], to format: Format, outer: Bool) {
        let replace = switch settings.afterConversion {
        case .keep: false
        case .replace: true
        case .split: outer
        }
        let service = service!
        let concurrency = service.isConcurrent(urls, to: format) ? ConversionService.maxConcurrentFiles : 1
        jobs.enqueue(Job(title: "\(Self.fileCount(urls.count)) → \(format.label)", fileCount: urls.count,
                         concurrency: concurrency) { [weak self] in
            let errors = await service.convert(urls, to: format, replaceOriginals: replace).errors
            if Task.isCancelled { throw CancellationError() }
            if errors.isEmpty {
                Log.jobs.info("Converted \(urls.count) file(s) to \(format.label, privacy: .public)\(replace ? ", originals moved to Trash" : "", privacy: .public)")
                self?.playSuccessSound()
            } else {
                self?.showErrorLater(L.conversionFailed, errors.map(\.localizedDescription).joined(separator: "\n\n"))
            }
        })
    }

    private func playSuccessSound() {
        if settings.playSound { NSSound(named: "Glass")?.play() }
    }

    /// "1 file", "3 files" – for job titles in the log.
    private static func fileCount(_ n: Int) -> String { n == 1 ? "1 file" : "\(n) files" }

    /// Shows the alert after the current job has finished, so the modal alert doesn't hold up the queue.
    private func showErrorLater(_ title: String, _ message: String) {
        DispatchQueue.main.async { [weak self] in self?.showError(title, message) }
    }

    private func showError(_ title: String, _ message: String) {
        Log.jobs.error("\(title, privacy: .public): \(message, privacy: .public)")
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        NSApp.activate()
        alert.runModal()
    }
}
