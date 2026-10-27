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
@MainActor
final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults: UserDefaults

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

    /// Whether a sound plays when a conversion, tool or action has finished.
    @Published var playSound: Bool {
        didSet { defaults.set(playSound, forKey: "playSound") }
    }

    /// Quality for lossy image formats (JPEG, HEIC, WebP, AVIF), 0.5 to 1.0.
    @Published var lossyQuality: Double {
        didSet {
            let clamped = Self.clamp(lossyQuality)
            // Assigning through @Published triggers didSet again, so only do it when something changes.
            if clamped != lossyQuality { lossyQuality = clamped; return }
            defaults.set(lossyQuality, forKey: "lossyQuality")
        }
    }

    nonisolated static let qualityRange: ClosedRange<Double> = 0.5...1.0

    private nonisolated static func clamp(_ quality: Double) -> Double {
        min(max(quality, qualityRange.lowerBound), qualityRange.upperBound)
    }

    /// `shared.language` and `shared.lossyQuality` for code off the main thread (`L`, conversions).
    /// Read from UserDefaults, which is thread-safe and which `didSet` updates on every change.
    nonisolated static var currentLanguage: AppLanguage { language(in: .standard) }
    nonisolated static var currentLossyQuality: Double { lossyQuality(in: .standard) }

    private nonisolated static func language(in defaults: UserDefaults) -> AppLanguage {
        AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .system
    }

    private nonisolated static func lossyQuality(in defaults: UserDefaults) -> Double {
        clamp(defaults.object(forKey: "lossyQuality") as? Double ?? 0.9)
    }

    private convenience init() { self.init(defaults: .standard) }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        playSound = defaults.object(forKey: "playSound") as? Bool ?? true
        lossyQuality = Self.lossyQuality(in: defaults)
        language = Self.language(in: defaults)
        afterConversion = AfterConversion(rawValue: defaults.string(forKey: "afterConversion") ?? "") ?? .keep
        disabledFormats = Set(defaults.stringArray(forKey: "disabledFormats") ?? [])
    }

    func isEnabled(_ format: Format) -> Bool { !disabledFormats.contains(format.ext) }

    func setEnabled(_ format: Format, _ enabled: Bool) {
        if enabled { disabledFormats.remove(format.ext) } else { disabledFormats.insert(format.ext) }
    }
}
