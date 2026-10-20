import Foundation
import UniformTypeIdentifiers

/// Optional: audio and video formats AVFoundation can't handle. Needs `brew install ffmpeg`.
/// Only offers formats whose encoder exists in the installed ffmpeg.
struct FFmpegConverter: Converter {
    let executable: URL
    private let options: [Format: [String]]

    /// Format → (required encoder, ffmpeg arguments between input and output).
    private static let recipes: [(Format, String?, [String])] = [
        (.mp4, "libx264", ["-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac"]),
        (.mov, "libx264", ["-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac"]),
        (.mkv, nil, ["-c", "copy"]),
        (.webm, "libvpx-vp9", ["-c:v", "libvpx-vp9", "-crf", "32", "-b:v", "0", "-c:a", "libopus"]),
        (.gif, nil, ["-vf", "fps=12,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse", "-loop", "0"]),
        (.mp3, "libmp3lame", ["-vn", "-c:a", "libmp3lame", "-q:a", "2"]),
        (.m4a, nil, ["-vn", "-c:a", "aac", "-b:a", "192k"]),
        (.wav, nil, ["-vn"]),
        (.flac, nil, ["-vn", "-c:a", "flac"]),
        (.ogg, "libvorbis", ["-vn", "-c:a", "libvorbis", "-q:a", "5"]),
        (.opus, "libopus", ["-vn", "-c:a", "libopus", "-b:a", "128k"]),
    ]
    private static let videoTargets: [Format] = [.mp4, .mov, .mkv, .webm, .gif, .mp3, .m4a]
    private static let audioTargets: [Format] = [.mp3, .m4a, .wav, .flac, .ogg, .opus]

    init?() {
        guard let executable = ExternalTool.find("ffmpeg") else { return nil }
        self.executable = executable
        let encoders = Self.availableEncoders(executable)
        var options: [Format: [String]] = [:]
        for (format, encoder, args) in Self.recipes where encoder.map(encoders.contains) ?? true {
            options[format] = args
        }
        self.options = options
    }

    func targets(for type: UTType) -> [Format] {
        let candidates: [Format]
        if type.conforms(to: .movie) { candidates = Self.videoTargets }
        else if type.conforms(to: .audio) { candidates = Self.audioTargets }
        else { return [] }
        return candidates.filter { options[$0] != nil }
    }

    func convert(_ input: URL, to format: Format, output: URL) async throws {
        guard let args = options[format] else { throw ConversionError(message: L.notSupported(format.label)) }
        try await ExternalTool.run(executable, ["-hide_banner", "-nostdin", "-i", input.path] + args + [output.path])
    }

    /// Reads encoder names from `ffmpeg -encoders` (synchronously, once at launch).
    private static func availableEncoders(_ executable: URL) -> Set<String> {
        let process = Process()
        process.executableURL = executable
        process.arguments = ["-hide_banner", "-encoders"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        // Lines like " A..... libmp3lame   libmp3lame MP3 …": the second field is the name.
        return Set(String(decoding: data, as: UTF8.self).split(separator: "\n").compactMap { line in
            let fields = line.split(separator: " ")
            return fields.count > 1 ? String(fields[1]) : nil
        })
    }
}
