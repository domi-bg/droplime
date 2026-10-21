import Foundation
import os
import UniformTypeIdentifiers

/// Optional: audio and video formats AVFoundation can't handle. Needs `brew install ffmpeg`.
/// Only offers formats whose encoder exists in the installed ffmpeg.
struct FFmpegConverter: Converter {
    let executable: URL
    private let probe: EncoderProbe

    /// Format → alternatives of (required encoder, ffmpeg arguments between input and output); the first available wins.
    private static let recipes: [(Format, [(String?, [String])])] = [
        (.mp4, [("h264_videotoolbox", ["-c:v", "h264_videotoolbox", "-q:v", "65", "-pix_fmt", "yuv420p", "-c:a", "aac"]),
                ("libx264", ["-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac"])]),
        (.mov, [("h264_videotoolbox", ["-c:v", "h264_videotoolbox", "-q:v", "65", "-pix_fmt", "yuv420p", "-c:a", "aac"]),
                ("libx264", ["-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac"])]),
        (.mkv, [(nil, ["-c", "copy"])]),
        (.webm, [("libvpx-vp9", ["-c:v", "libvpx-vp9", "-crf", "32", "-b:v", "0", "-c:a", "libopus"])]),
        (.gif, [(nil, ["-vf", "fps=12,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse", "-loop", "0"])]),
        (.mp3, [("libmp3lame", ["-vn", "-c:a", "libmp3lame", "-q:a", "2"])]),
        (.m4a, [(nil, ["-vn", "-c:a", "aac", "-b:a", "192k"])]),
        (.wav, [(nil, ["-vn"])]),
        (.flac, [(nil, ["-vn", "-c:a", "flac"])]),
        (.ogg, [("libvorbis", ["-vn", "-c:a", "libvorbis", "-q:a", "5"])]),
        (.opus, [("libopus", ["-vn", "-c:a", "libopus", "-b:a", "128k"])]),
    ]
    private static let videoTargets: [Format] = [.mp4, .mov, .mkv, .webm, .gif, .mp3, .m4a]
    private static let audioTargets: [Format] = [.mp3, .m4a, .wav, .flac, .ogg, .opus]

    /// Cheap: only looks for the executable. The encoder list is read once per executable in the background.
    init?() {
        guard let executable = ExternalTool.find("ffmpeg") else { return nil }
        self.executable = executable
        probe = EncoderProbe.shared(for: executable)
    }

    /// Format → ffmpeg arguments, for the formats whose encoder exists. Waits for the probe on first use.
    private var options: [Format: [String]] { probe.options }

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

    /// Format → arguments of the first alternative whose encoder is available.
    fileprivate static func options(encoders: Set<String>) -> [Format: [String]] {
        var options: [Format: [String]] = [:]
        for (format, alternatives) in recipes {
            if let recipe = alternatives.first(where: { $0.0.map(encoders.contains) ?? true }) {
                options[format] = recipe.1
            }
        }
        return options
    }

    /// Reads encoder names from `ffmpeg -encoders` (synchronously; called on a background queue).
    fileprivate static func availableEncoders(_ executable: URL) -> Set<String> {
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

/// Runs `ffmpeg -encoders` once per executable on a background queue and caches the result,
/// so launching the app and re-detecting tools never wait for ffmpeg.
private final class EncoderProbe: @unchecked Sendable {
    private static let cache = OSAllocatedUnfairLock(initialState: [URL: EncoderProbe]())

    static func shared(for executable: URL) -> EncoderProbe {
        cache.withLock { probes in
            if let probe = probes[executable] { return probe }
            let probe = EncoderProbe(executable)
            probes[executable] = probe
            return probe
        }
    }

    private let done = DispatchGroup()
    private var result: [Format: [String]] = [:]

    private init(_ executable: URL) {
        done.enter()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let encoders = FFmpegConverter.availableEncoders(executable)
            let options = FFmpegConverter.options(encoders: encoders)
            result = options
            Log.tools.info("ffmpeg has \(encoders.count) encoders; offers \(options.keys.map(\.label).sorted().joined(separator: ", "), privacy: .public)")
            done.leave()
        }
    }

    /// Blocks only until the first probe has finished; afterwards returns immediately.
    var options: [Format: [String]] {
        done.wait()
        return result
    }
}
