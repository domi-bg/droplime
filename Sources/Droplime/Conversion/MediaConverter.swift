import AVFoundation
import UniformTypeIdentifiers

/// Video via AVFoundation, audio via the built-in `afconvert`.
struct MediaConverter: Converter {
    /// Only types AVFoundation can actually read (so e.g. no MKV or WebM).
    private static let readable = Set(AVURLAsset.audiovisualTypes().map(\.rawValue))
    /// Format → (file format, data format) for afconvert.
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
