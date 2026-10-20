import AppKit

/// Actions in the Ctrl wheel. They also work with folders and mixed selections.
enum FileAction: String, CaseIterable {
    case airDrop, copy, move, copyPath, terminal, float

    var label: String {
        switch self {
        case .airDrop: return L.actionAirDrop
        case .copy: return L.actionCopy
        case .move: return L.actionMove
        case .copyPath: return L.actionPath
        case .terminal: return L.actionTerminal
        case .float: return L.actionFloat
        }
    }

    /// Performs the action. Returns false if the user cancelled.
    @MainActor
    func perform(on urls: [URL]) throws -> Bool {
        switch self {
        case .airDrop:
            guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: urls) else {
                throw ConversionError(message: L.airDropUnavailable)
            }
            NSApp.activate()
            service.perform(withItems: urls)
        case .copy, .move:
            guard let folder = Self.chooseFolder(title: self == .copy ? L.copyTo : L.moveTo) else { return false }
            if self == .copy { try Self.copy(urls, to: folder) } else { try Self.move(urls, to: folder) }
        case .copyPath:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(Self.pathText(urls), forType: .string)
        case .terminal:
            guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
                throw ConversionError(message: L.terminalNotFound)
            }
            NSWorkspace.shared.open(Self.folders(of: urls), withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
        case .float:
            FloatPanel.show(urls)
        }
        return true
    }

    // MARK: - Building blocks (no UI, so they're testable)

    /// Paths, one per line.
    static func pathText(_ urls: [URL]) -> String {
        urls.map(\.path).joined(separator: "\n")
    }

    /// Folders to open in Terminal: the containing folder for files, without duplicates.
    static func folders(of urls: [URL]) -> [URL] {
        var seen = Set<URL>()
        return urls.map { $0.hasDirectoryPath ? $0 : $0.deletingLastPathComponent() }
            .filter { seen.insert($0.standardizedFileURL).inserted }
    }

    @discardableResult
    static func copy(_ urls: [URL], to folder: URL) throws -> [URL] {
        try urls.map { url in
            let destination = uniqueDestination(for: url, in: folder)
            try FileManager.default.copyItem(at: url, to: destination)
            return destination
        }
    }

    @discardableResult
    static func move(_ urls: [URL], to folder: URL) throws -> [URL] {
        try urls.compactMap { url in
            // Already in that folder: nothing to do.
            guard url.deletingLastPathComponent().standardizedFileURL != folder.standardizedFileURL else { return nil }
            let destination = uniqueDestination(for: url, in: folder)
            try FileManager.default.moveItem(at: url, to: destination)
            return destination
        }
    }

    /// "report.pdf" → "report 2.pdf" if taken; folders without extension work the same.
    static func uniqueDestination(for url: URL, in folder: URL) -> URL {
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        func named(_ name: String) -> URL {
            ext.isEmpty ? folder.appendingPathComponent(name) : folder.appendingPathComponent(name).appendingPathExtension(ext)
        }
        var candidate = named(base)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = named("\(base) \(n)")
            n += 1
        }
        return candidate
    }

    private static let lastFolderKey = "lastActionFolder"

    @MainActor
    private static func chooseFolder(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = L.choose
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        if let last = UserDefaults.standard.url(forKey: lastFolderKey) { panel.directoryURL = last }
        NSApp.activate()
        guard panel.runModal() == .OK, let folder = panel.url else { return nil }
        UserDefaults.standard.set(folder, forKey: lastFolderKey)
        return folder
    }
}
