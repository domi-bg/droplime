import AppKit
import Testing
import UniformTypeIdentifiers
@testable import Droplime

/// Image conversions run several files at a time; results must stay as with serial conversion.
struct ConcurrentConversionTests {
    let folder: URL
    let service = ConversionService(converters: [ImageConverter(), PDFConverter()])

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("DroplimeConcurrent-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    /// A small solid image in the given format.
    private func image(_ name: String, type: NSBitmapImageRep.FileType = .png) throws -> URL {
        let url = folder.appendingPathComponent(name)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 40, pixelsHigh: 30, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.systemGreen.setFill()
        NSRect(x: 0, y: 0, width: 40, height: 30).fill()
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: type, properties: [:])!.write(to: url)
        return url
    }

    @Test func imageConverterIsConcurrent() throws {
        let urls = [try image("a.png"), try image("b.png")]
        #expect(service.isConcurrent(urls, to: .jpg))
        #expect(!ConversionService(converters: [DocumentConverter()]).isConcurrent(urls, to: .jpg))
    }

    @Test func manyImagesKeepOrderAndErrors() async throws {
        var images = try (1...7).map { try image("photo \($0).png") }
        // Same base name, different types: both want "twin.jpg", so the outputs must not collide.
        images += [try image("twin.png"), try image("twin.tiff", type: .tiff)]
        let broken = folder.appendingPathComponent("broken.png")
        try Data("not an image".utf8).write(to: broken)
        let inputs = Array(images[..<3]) + [broken] + Array(images[3...])
        var trashed: [URL] = []

        let result = await service.convert(inputs, to: .jpg, replaceOriginals: true, trash: { trashed.append($0) })

        #expect(result.succeeded == images)
        #expect(result.errors.count == 1)
        #expect(trashed == images)
        let outputs = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".jpg") }
        #expect(outputs.count == images.count)
        #expect(Set(outputs).isSuperset(of: ["twin.jpg", "twin 2.jpg"]))
        #expect(!outputs.contains("broken.jpg"))
    }

    @Test func cancelledConversionLeavesNoOutput() async throws {
        let images = try (1...6).map { try image("cancel \($0).png") }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await service.convert(images, to: .jpg)
        }
        let result = await task.value
        #expect(result.succeeded.isEmpty)
        #expect(result.errors.count == images.count)
        #expect(result.errors.allSatisfy { $0 is CancellationError })
        let outputs = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".jpg") }
        #expect(outputs.isEmpty)
    }

    /// Writes part of the output, then hangs until cancelled.
    private struct HangingConverter: Converter {
        func targets(for type: UTType) -> [Format] { [.txt] }
        func convert(_ input: URL, to format: Format, output: URL) async throws {
            try Data("partial".utf8).write(to: output)
            try await Task.sleep(for: .seconds(30))
        }
    }

    @Test func cancelRemovesHalfWrittenOutput() async throws {
        let input = try image("hang.png")
        let service = ConversionService(converters: [HangingConverter()])
        let task = Task { await service.convert([input], to: .txt) }
        try await Task.sleep(for: .milliseconds(100))
        #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("hang.txt").path))
        task.cancel()
        let result = await task.value
        #expect(result.succeeded.isEmpty)
        #expect(result.errors.count == 1 && result.errors.first is CancellationError)
        #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("hang.txt").path))
    }
}
