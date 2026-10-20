import Foundation

enum AfterConversion: String, CaseIterable, Identifiable {
    case keep, replace, split

    var id: String { rawValue }

    var label: String {
        switch self {
        case .keep: return L.afterKeep
        case .replace: return L.afterReplace
        case .split: return L.afterSplit
        }
    }
}

/// Settings, stored in UserDefaults.
final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: "language") }
    }

    @Published var afterConversion: AfterConversion {
        didSet { defaults.set(afterConversion.rawValue, forKey: "afterConversion") }
    }

    /// File extensions of target formats that should never appear in the wheel.
    @Published private(set) var disabledFormats: Set<String> {
        didSet { defaults.set(Array(disabledFormats).sorted(), forKey: "disabledFormats") }
    }

    private init() {
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .system
        afterConversion = AfterConversion(rawValue: defaults.string(forKey: "afterConversion") ?? "") ?? .keep
        disabledFormats = Set(defaults.stringArray(forKey: "disabledFormats") ?? [])
    }

    func isEnabled(_ format: Format) -> Bool { !disabledFormats.contains(format.ext) }

    func setEnabled(_ format: Format, _ enabled: Bool) {
        if enabled { disabledFormats.remove(format.ext) } else { disabledFormats.insert(format.ext) }
    }
}
