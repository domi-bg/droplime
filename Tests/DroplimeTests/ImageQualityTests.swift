import AppKit
import Testing
@testable import Droplime

struct ImageQualityTests {
    /// 256×256 PNG with random pixels, so JPEG size depends strongly on quality.
    private func noisyPNG(in dir: URL) throws -> URL {
        let size = 256
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let data = try #require(rep.bitmapData)
        for i in 0..<(rep.bytesPerRow * size) { data[i] = UInt8.random(in: 0...255) }
        let url = dir.appendingPathComponent("noise.png")
        try #require(rep.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    private func jpegSize(of input: URL, quality: Double, in dir: URL) async throws -> Int {
        let output = dir.appendingPathComponent("out-\(quality).jpg")
        try await ImageConverter(quality: { quality }).convert(input, to: .jpg, output: output)
        return try FileManager.default.attributesOfItem(atPath: output.path)[.size] as! Int
    }

    @Test func lowerQualityGivesSmallerJPEG() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("DroplimeQuality-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let input = try noisyPNG(in: dir)
        let low = try await jpegSize(of: input, quality: 0.3, in: dir)
        let high = try await jpegSize(of: input, quality: 1.0, in: dir)
        #expect(low < high)
    }
}
