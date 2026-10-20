import AppKit
import AVFoundation
import PDFKit
import Testing
@testable import Droplime

/// Erzeugt Beispieldateien und wandelt jede in alle angebotenen Formate um.
@Suite(.serialized)
struct ConversionTests {
    let folder: URL
    let service: ConversionService

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("DroplimeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let optional: [Converter?] = [LibreOfficeConverter(), PandocConverter()]
        service = ConversionService(converters: [ImageConverter(), PDFConverter()] + optional.compactMap { $0 }
            + [DocumentConverter(), MediaConverter()] + [FFmpegConverter()].compactMap { $0 })
    }

    /// Wandelt `input` in jedes angebotene Format um und prüft, dass nicht-leere Dateien entstehen.
    private func convertToAllTargets(_ input: URL, expecting expected: [Format]) async throws {
        let targets = service.targets(for: [input])
        for format in expected {
            #expect(targets.contains(format), "\(input.lastPathComponent) sollte \(format.label) anbieten")
        }
        for format in targets {
            let errors = await service.convert([input], to: format).errors
            #expect(errors.isEmpty, "\(input.lastPathComponent) → \(format.label): \(errors)")
            let produced = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey])
                .filter { $0.pathExtension == format.ext && $0 != input }
            #expect(!produced.isEmpty, "\(input.lastPathComponent) → \(format.label): keine Datei")
            for url in produced {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                #expect(size > 0, "\(url.lastPathComponent) ist leer")
                try FileManager.default.removeItem(at: url)
            }
        }
    }

    private func sampleImage() throws -> URL {
        let url = folder.appendingPathComponent("bild.png")
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 48, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.systemOrange.setFill()
        NSRect(x: 0, y: 0, width: 64, height: 48).fill()
        NSGraphicsContext.current = nil
        try rep.representation(using: .png, properties: [:])!.write(to: url)
        return url
    }

    @Test func pdfWithoutTextFails() async throws {
        let image = NSImage(contentsOf: try sampleImage())!
        let document = PDFDocument()
        document.insert(PDFPage(image: image)!, at: 0)
        let url = folder.appendingPathComponent("scan.pdf")
        #expect(document.write(to: url))
        let errors = await service.convert([url], to: .txt).errors
        #expect(errors.count == 1)
    }

    @Test func replaceTrashesOnlySuccessfulOriginals() async throws {
        let image = try sampleImage()
        let broken = folder.appendingPathComponent("kaputt.png")
        try Data("kein Bild".utf8).write(to: broken)
        var trashed: [URL] = []

        let result = await service.convert([image, broken], to: .jpg, replaceOriginals: true, trash: { trashed.append($0) })

        #expect(result.succeeded == [image])
        #expect(result.errors.count == 1)
        #expect(trashed == [image])
        #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("bild.jpg").path))
    }

    @Test func image() async throws {
        try await convertToAllTargets(try sampleImage(), expecting: [.jpg, .heic, .tiff, .pdf])
    }

    @Test func pdfSplitsPages() async throws {
        let url = folder.appendingPathComponent("dokument.pdf")
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        let context = CGContext(url as CFURL, mediaBox: &box, nil)!
        for page in 1...2 {
            context.beginPDFPage(nil)
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            NSString(string: "Seite \(page)").draw(at: NSPoint(x: 72, y: 700), withAttributes: [.font: NSFont.systemFont(ofSize: 24)])
            NSGraphicsContext.current = nil
            context.endPDFPage()
        }
        context.closePDF()

        let errors = await service.convert([url], to: .png).errors
        #expect(errors.isEmpty)
        let pages = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".png") }
        #expect(pages.sorted() == ["dokument\(L.pageSuffix(1)).png", "dokument\(L.pageSuffix(2)).png"])
        pages.forEach { try? FileManager.default.removeItem(at: folder.appendingPathComponent($0)) }

        try await convertToAllTargets(url, expecting: [.png, .jpg, .txt])
    }

    @Test func documents() async throws {
        let rtf = folder.appendingPathComponent("text.rtf")
        let text = NSAttributedString(string: String(repeating: "Droplime wandelt Dateien um. ", count: 400))
        try text.rtf(from: NSRange(location: 0, length: text.length))!.write(to: rtf)
        try await convertToAllTargets(rtf, expecting: [.docx, .pdf, .txt, .html])

        _ = await service.convert([rtf], to: .docx)
        try FileManager.default.removeItem(at: rtf)
        try await convertToAllTargets(folder.appendingPathComponent("text.docx"), expecting: [.pdf, .rtf, .txt])
    }

    @Test func audio() async throws {
        let wav = folder.appendingPathComponent("ton.wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
        buffer.frameLength = 44100
        for i in 0..<Int(buffer.frameLength) { buffer.floatChannelData![0][i] = sin(Float(i) * 0.05) * 0.5 }
        try AVAudioFile(forWriting: wav, settings: format.settings).write(from: buffer)
        let expected: [Format] = FFmpegConverter() == nil ? [.m4a, .aiff] : [.m4a, .aiff, .mp3, .flac]
        try await convertToAllTargets(wav, expecting: expected)
    }

    @Test(.enabled(if: FFmpegConverter() != nil, "Braucht ffmpeg, um ein Testvideo zu erzeugen"))
    func video() async throws {
        let mov = folder.appendingPathComponent("film.mov")
        try await ExternalTool.run(ExternalTool.find("ffmpeg")!, [
            "-hide_banner", "-f", "lavfi", "-i", "testsrc=duration=1:size=320x240:rate=10",
            "-f", "lavfi", "-i", "sine=duration=1", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", mov.path,
        ])
        try await convertToAllTargets(mov, expecting: [.mp4, .m4a, .gif, .mp3, .mkv])
    }
}
