import AVFoundation
import UniformTypeIdentifiers

/// Video über AVFoundation, Audio über das in macOS eingebaute `afconvert`.
struct MediaConverter: Converter {
    /// Nur Typen, die AVFoundation wirklich lesen kann (also z. B. kein MKV oder WebM).
    private static let readable = Set(AVURLAsset.audiovisualTypes().map(\.rawValue))
    /// Format → (Dateiformat, Datenformat) für afconvert.
    private static let afconvertFormats: [Format: (String, String)] = [
        .m4a: ("m4af", "aac"), .wav: ("WAVE", "LEI16"), .aiff: ("AIFF", "BEI16"),
    ]

    func targets(for type: UTType) -> [Format] {
        guard Self.readable.contains(type.identifier) else { return [] }
        if type.conforms(to: .movie) { return [.mp4, .mov, .m4a] }
        if type.conforms(to: .audio) { return [.m4a, .wav, .aiff] }
        return []
    }

    func convert(_ input: URL, to format: Format, output: URL) async throws {
        let isVideo = ConversionService.type(of: input)?.conforms(to: .movie) ?? false
        if !isVideo, let (file, data) = Self.afconvertFormats[format] {
            try await ExternalTool.run(URL(fileURLWithPath: "/usr/bin/afconvert"),
                                       ["-f", file, "-d", data, input.path, output.path])
            return
        }
        let preset = format == .m4a ? AVAssetExportPresetAppleM4A : AVAssetExportPresetHighestQuality
        let fileType: AVFileType = switch format {
        case .mp4: .mp4
        case .mov: .mov
        default: .m4a
        }
        guard let session = AVAssetExportSession(asset: AVURLAsset(url: input), presetName: preset) else {
            throw ConversionError(message: L.exportFailed)
        }
        session.outputURL = output
        session.outputFileType = fileType
        await session.export()
        if session.status != .completed {
            throw ConversionError(message: session.error?.localizedDescription ?? L.exportFailed)
        }
    }
}
