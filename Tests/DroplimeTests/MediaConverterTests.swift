import AVFoundation
import Testing
@testable import Droplime

struct MediaConverterTests {
    @Test(.enabled(if: ExternalTool.find("ffmpeg") != nil, "Needs ffmpeg to create a test video"))
    func movToMp4KeepsH264() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DroplimeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let mov = folder.appendingPathComponent("movie.mov")
        try await ExternalTool.run(ExternalTool.find("ffmpeg")!, [
            "-hide_banner", "-f", "lavfi", "-i", "testsrc=duration=1:size=320x240:rate=10",
            "-f", "lavfi", "-i", "sine=duration=1", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", mov.path,
        ])
        let mp4 = folder.appendingPathComponent("movie.mp4")
        try await MediaConverter().convert(mov, to: .mp4, output: mp4)

        let asset = AVURLAsset(url: mp4)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let descriptions = try await track.load(.formatDescriptions)
        let description = try #require(descriptions.first)
        #expect(CMFormatDescriptionGetMediaSubType(description) == kCMVideoCodecType_H264)
        let seconds = try await asset.load(.duration).seconds
        #expect(abs(seconds - 1) < 0.3, "duration \(seconds)")
    }
}
