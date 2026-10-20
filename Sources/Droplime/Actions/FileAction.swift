import AppKit

/// Aktionen im Ctrl-Rad. Funktionieren auch mit Ordnern und gemischten Auswahlen.
enum FileAction: String, CaseIterable {
    case airDrop, copy, move, copyPath, terminal, float

    var label: String {
        switch self {
        case .airDrop: return "AirDrop"
        case .copy: return "Kopieren"
        case .move: return "Verschieben"
        case .copyPath: return "Pfad"
        case .terminal: return "Terminal"
        case .float: return "Float"
        }
    }

    /// Führt die Aktion aus. Gibt false zurück, wenn der Nutzer abgebrochen hat.
    @MainActor
    func perform(on urls: [URL]) throws -> Bool {
        switch self {
        case .airDrop:
            guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: urls) else {
                throw ConversionError(message: "AirDrop ist auf diesem Mac nicht verfügbar.")
            }
            NSApp.activate()
            service.perform(withItems: urls)
        case .copy, .move:
            guard let folder = Self.chooseFolder(title: self == .copy ? "Kopieren nach" : "Verschieben nach") else { return false }
            if self == .copy { try Self.copy(urls, to: folder) } else { try Self.move(urls, to: folder) }
        case .copyPath:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(Self.pathText(urls), forType: .string)
        case .terminal:
            guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
                throw ConversionError(message: "Terminal wurde nicht gefunden.")
            }
            NSWorkspace.shared.open(Self.folders(of: urls), withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
        case .float:
            FloatPanel.show(urls)
        }
        return true
    }

    // MARK: - Bausteine (ohne Oberfläche, damit testbar)

    /// Pfade, einer pro Zeile.
    static func pathText(_ urls: [URL]) -> String {
        urls.map(\.path).joined(separator: "\n")
    }

    /// Ordner zum Öffnen im Terminal: bei Dateien der enthaltende Ordner, ohne Doppelte.
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
            // Liegt die Datei schon dort, gibt es nichts zu tun.
            guard url.deletingLastPathComponent().standardizedFileURL != folder.standardizedFileURL else { return nil }
            let destination = uniqueDestination(for: url, in: folder)
            try FileManager.default.moveItem(at: url, to: destination)
            return destination
        }
    }

    /// "bericht.pdf" → "bericht 2.pdf", falls schon vorhanden; Ordner ohne Endung genauso.
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
        panel.prompt = title.components(separatedBy: " ").first
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
