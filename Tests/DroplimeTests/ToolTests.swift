import AppKit
import AVFoundation
import ImageIO
import PDFKit
import Testing
import UniformTypeIdentifiers
@testable import Droplime

struct ToolTests {
    let folder: URL
    let service = ToolService.standard()

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("DroplimeTools-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func labels(_ urls: [URL]) -> [String] { service.tools(for: urls).map(\.label) }

    private func tool(_ label: String, for urls: [URL]) throws -> Tool {
        try #require(service.tools(for: urls).first { $0.label == label })
    }

    /// JPEG 80×40 mit GPS-Daten und EXIF-Ausrichtung 6 (= 90° gedreht anzeigen).
    private func photo() throws -> URL {
        let url = folder.appendingPathComponent("foto.jpg")
        let context = CGContext(data: nil, width: 80, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(red: 0.6, green: 0.8, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 80, height: 40))
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 47.37, kCGImagePropertyGPSLatitudeRef: "N"],
        ] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    private func properties(_ url: URL) -> [CFString: Any] {
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! [CFString: Any]
    }

    private func pdf(_ name: String, pages: Int) -> URL {
        let url = folder.appendingPathComponent(name)
        var box = CGRect(x: 0, y: 0, width: 200, height: 300)
        let context = CGContext(url as CFURL, mediaBox: &box, nil)!
        for _ in 0..<pages { context.beginPDFPage(nil); context.endPDFPage() }
        context.closePDF()
        return url
    }

    @Test func offersMatchingTools() throws {
        let photo = try photo()
        let a = pdf("a.pdf", pages: 2)
        #expect(labels([photo]) == ["Verkleinern", "Drehen", "Ohne Metadaten", "ZIP"])
        #expect(labels([a]) == ["Teilen", "Komprimieren", "Drehen", "ZIP"])
        #expect(labels([a, photo]) == ["Zusammenfügen", "ZIP"])
    }

    @Test func imageTools() async throws {
        let photo = try photo()

        let small = try await tool("Verkleinern", for: [photo]).run([photo])[0]
        // Ausrichtung angewendet: angezeigt 40×80, halbiert 20×40.
        #expect(properties(small)[kCGImagePropertyPixelWidth] as? Int == 20)
        #expect(properties(small)[kCGImagePropertyPixelHeight] as? Int == 40)

        let rotated = try await tool("Drehen", for: [photo]).run([photo])[0]
        #expect(properties(rotated)[kCGImagePropertyPixelWidth] as? Int == 80)

        let clean = try await tool("Ohne Metadaten", for: [photo]).run([photo])[0]
        #expect(properties(photo)[kCGImagePropertyGPSDictionary] != nil)
        #expect(properties(clean)[kCGImagePropertyGPSDictionary] == nil)
        #expect(properties(clean)[kCGImagePropertyOrientation] as? Int == 6)
        #expect(clean.lastPathComponent == "foto (ohne Metadaten).jpg")
    }

    @Test func pdfTools() async throws {
        let a = pdf("a.pdf", pages: 2), b = pdf("b.pdf", pages: 3)

        let merged = try await tool("Zusammenfügen", for: [a, b]).run([a, b])
        #expect(merged.map(\.lastPathComponent) == ["Zusammengefügt.pdf"])
        #expect(PDFDocument(url: merged[0])?.pageCount == 5)

        let pages = try await tool("Teilen", for: [b]).run([b])
        #expect(pages.count == 3)
        #expect(PDFDocument(url: pages[2])?.pageCount == 1)

        let rotated = try await tool("Drehen", for: [a]).run([a])[0]
        #expect(PDFDocument(url: rotated)?.page(at: 0)?.rotation == 90)

        let compressed = try await tool("Komprimieren", for: [a]).run([a])[0]
        #expect(PDFDocument(url: compressed)?.pageCount == 2)

        let single = pdf("einzeln.pdf", pages: 1)
        await #expect(throws: ConversionError.self) { try await tool("Teilen", for: [single]).run([single]) }
    }

    @Test func zipRoundTrip() async throws {
        let sub = folder.appendingPathComponent("Ordner", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data("hallo".utf8).write(to: sub.appendingPathComponent("datei.txt"))
        let note = folder.appendingPathComponent("notiz.txt")
        try Data("notiz".utf8).write(to: note)

        let zip = try await tool("ZIP", for: [sub, note]).run([sub, note])[0]
        #expect(zip.lastPathComponent == "Archiv.zip")
        #expect(labels([zip]) == ["Entpacken"])

        let unpacked = try await tool("Entpacken", for: [zip]).run([zip])[0]
        #expect(try String(contentsOf: unpacked.appendingPathComponent("Ordner/datei.txt"), encoding: .utf8) == "hallo")
        #expect(FileManager.default.fileExists(atPath: unpacked.appendingPathComponent("notiz.txt").path))
    }

    @Test(.enabled(if: ExternalTool.find("ffmpeg") != nil, "Braucht ffmpeg, um ein Testvideo zu erzeugen"))
    func videoTools() async throws {
        let mov = folder.appendingPathComponent("film.mov")
        try await ExternalTool.run(ExternalTool.find("ffmpeg")!, [
            "-hide_banner", "-f", "lavfi", "-i", "testsrc=duration=1:size=320x240:rate=10",
            "-f", "lavfi", "-i", "sine=duration=1", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", mov.path,
        ])
        #expect(labels([mov]) == ["Komprimieren", "Ohne Ton", "ZIP"])

        let silent = try await tool("Ohne Ton", for: [mov]).run([mov])[0]
        #expect(try await AVURLAsset(url: silent).loadTracks(withMediaType: .audio).isEmpty)
        #expect(try await !AVURLAsset(url: silent).loadTracks(withMediaType: .video).isEmpty)

        let compressed = try await tool("Komprimieren", for: [mov]).run([mov])[0]
        #expect(try await !AVURLAsset(url: compressed).loadTracks(withMediaType: .video).isEmpty)
    }
}
