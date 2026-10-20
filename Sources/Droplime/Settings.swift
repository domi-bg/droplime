import Foundation

enum AfterConversion: String, CaseIterable, Identifiable {
    case keep, replace, split

    var id: String { rawValue }

    var label: String {
        switch self {
        case .keep: return "Original behalten"
        case .replace: return "Original ersetzen (in den Papierkorb)"
        case .split: return "Im Rad wählen: innen behalten, außen ersetzen"
        }
    }
}

/// Einstellungen, gespeichert in UserDefaults.
final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    @Published var afterConversion: AfterConversion {
        didSet { defaults.set(afterConversion.rawValue, forKey: "afterConversion") }
    }

    /// Dateiendungen der Zielformate, die nie im Rad erscheinen sollen.
    @Published private(set) var disabledFormats: Set<String> {
        didSet { defaults.set(Array(disabledFormats).sorted(), forKey: "disabledFormats") }
    }

    private init() {
        afterConversion = AfterConversion(rawValue: defaults.string(forKey: "afterConversion") ?? "") ?? .keep
        disabledFormats = Set(defaults.stringArray(forKey: "disabledFormats") ?? [])
    }

    func isEnabled(_ format: Format) -> Bool { !disabledFormats.contains(format.ext) }

    func setEnabled(_ format: Format, _ enabled: Bool) {
        if enabled { disabledFormats.remove(format.ext) } else { disabledFormats.insert(format.ext) }
    }
}
