import AppKit

enum WheelMode {
    case convert, tools, actions

    /// Shift → Convert, Cmd → Tools, Ctrl → Actions.
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
}
