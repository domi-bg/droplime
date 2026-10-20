import AVFoundation
import UniformTypeIdentifiers

private let playable = Set(AVURLAsset.audiovisualTypes().map(\.rawValue))

private func export(_ asset: AVAsset, preset: String, fileType: AVFileType, to output: URL) async throws {
    guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
        throw ConversionError(message: "Export nicht möglich.")
    }
    session.outputURL = output
    session.outputFileType = fileType
    await session.export()
    if session.status != .completed {
        throw ConversionError(message: session.error?.localizedDescription ?? "Export fehlgeschlagen.")
    }
}

private func isVideo(_ type: UTType) -> Bool { type.conforms(to: .movie) && playable.contains(type.identifier) }

/// Video in HEVC, höchstens 1080p – meist deutlich kleiner bei kaum sichtbarem Unterschied.
struct CompressVideoTool: Tool {
    let label = "Komprimieren"

    func applies(to types: [UTType]) -> Bool { types.allSatisfy(isVideo) }

    func run(_ urls: [URL]) async throws -> [URL] {
        try await eachFile(urls) { url in
            let output = ConversionService.outputURL(for: url, ext: "mp4", suffix: " (komprimiert)")
            try await export(AVURLAsset(url: url), preset: AVAssetExportPresetHEVC1920x1080, fileType: .mp4, to: output)
            return output
        }
    }
}

/// Entfernt die Tonspur, ohne das Bild neu zu kodieren.
struct RemoveAudioTool: Tool {
    let label = "Ohne Ton"

    func applies(to types: [UTType]) -> Bool { types.allSatisfy(isVideo) }

    func run(_ urls: [URL]) async throws -> [URL] {
        try await eachFile(urls) { url in
            let asset = AVURLAsset(url: url)
            let composition = AVMutableComposition()
            let duration = try await asset.load(.duration)
            for track in try await asset.loadTracks(withMediaType: .video) {
                let target = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
                try target?.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: track, at: .zero)
                target?.preferredTransform = try await track.load(.preferredTransform)
            }
            let isMP4 = ["mp4", "m4v"].contains(url.pathExtension.lowercased())
            let output = ConversionService.outputURL(for: url, ext: isMP4 ? "mp4" : "mov", suffix: " (ohne Ton)")
            try await export(composition, preset: AVAssetExportPresetPassthrough, fileType: isMP4 ? .mp4 : .mov, to: output)
            return output
        }
    }
}

/// Audio als AAC mit 96 kbit/s.
struct CompressAudioTool: Tool {
    let label = "Komprimieren"

    func applies(to types: [UTType]) -> Bool {
        types.allSatisfy { $0.conforms(to: .audio) && playable.contains($0.identifier) }
    }

    func run(_ urls: [URL]) async throws -> [URL] {
        try await eachFile(urls) { url in
            let output = ConversionService.outputURL(for: url, ext: "m4a", suffix: " (komprimiert)")
            try await ExternalTool.run(URL(fileURLWithPath: "/usr/bin/afconvert"),
                                       ["-f", "m4af", "-d", "aac", "-b", "96000", url.path, output.path])
            return output
        }
    }
}
