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
        let fileType: AVFileType = switch format {
        case .mp4: .mp4
        case .mov: .mov
        default: .m4a
        }
        let asset = AVURLAsset(url: input)
        // MOV <-> MP4: if the tracks fit the target container, remux instead of re-encoding.
        if format != .m4a, await Self.canRemux(asset, to: fileType) {
            if (try? await Self.export(asset, preset: AVAssetExportPresetPassthrough, fileType: fileType, output: output)) != nil {
                return
            }
            try? FileManager.default.removeItem(at: output)
        }
        let preset = format == .m4a ? AVAssetExportPresetAppleM4A : AVAssetExportPresetHighestQuality
        try await Self.export(asset, preset: preset, fileType: fileType, output: output)
    }

    /// True if the passthrough preset can write the asset's tracks as `fileType`.
    private static func canRemux(_ asset: AVAsset, to fileType: AVFileType) async -> Bool {
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else { return false }
        return await session.compatibleFileTypes.contains(fileType)
    }

    private static func export(_ asset: AVAsset, preset: String, fileType: AVFileType, output: URL) async throws {
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
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
