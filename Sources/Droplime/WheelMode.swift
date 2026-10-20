import AppKit

enum WheelMode {
    case convert, tools, actions

    /// Shift → Konvertieren, Cmd → Werkzeuge, Ctrl → Aktionen.
    init?(pressed flags: NSEvent.ModifierFlags) {
        if flags.contains(.shift) { self = .convert }
        else if flags.contains(.command) { self = .tools }
        else if flags.contains(.control) { self = .actions }
        else { return nil }
    }

    var title: String {
        switch self {
        case .convert: return L.modeConvert
        case .tools: return L.modeTools
        case .actions: return L.modeActions
        }
    }

    /// Feste Einträge; beim Konvertieren und bei Werkzeugen hängen sie von den gezogenen Dateien ab.
    var items: [String] {
        switch self {
        case .convert, .tools: return []
        case .actions: return FileAction.allCases.map(\.label)
        }
    }
}
