import AppKit
import os
import PDFKit
import Testing
@testable import Droplime

/// A 200×300 page with its top-left quarter (100×150) filled black, converted at scale 2.
struct PDFConverterTests {
    private func render(rotation: Int) async throws -> CGImage {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("DroplimePDF-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let pdf = dir.appendingPathComponent("in.pdf")
        var box = CGRect(x: 0, y: 0, width: 200, height: 300)
        let context = try #require(CGContext(pdf as CFURL, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        context.setFillColor(.black)
        context.fill(CGRect(x: 0, y: 150, width: 100, height: 150))
        context.endPDFPage()
        context.closePDF()

        let document = try #require(PDFDocument(url: pdf))
        document.page(at: 0)?.rotation = rotation
        let rotated = dir.appendingPathComponent("rotated.pdf")
        #expect(document.write(to: rotated))

        let png = dir.appendingPathComponent("out.png")
        try await PDFConverter().convert(rotated, to: .png, output: png)
        let source = try #require(CGImageSourceCreateWithURL(png as CFURL, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    /// True when the pixel at (x, y), measured from the top-left, is dark.
    private func isBlack(_ image: CGImage, _ x: Int, _ y: Int) throws -> Bool {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                             space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        // Draw so that pixel (x, y) from the top-left lands on the 1×1 canvas.
        context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
        return pixel[0] < 50
    }

    @Test func upright() async throws {
        let image = try await render(rotation: 0)
        #expect((image.width, image.height) == (400, 600))
        #expect(try isBlack(image, 100, 150))
        #expect(try !isBlack(image, 300, 150))
        #expect(try !isBlack(image, 100, 450))
    }

    @Test func rotated90() async throws {
        let image = try await render(rotation: 90)
        #expect((image.width, image.height) == (600, 400))
        // Clockwise rotation moves the top-left quarter to the top-right.
        #expect(try isBlack(image, 450, 100))
        #expect(try !isBlack(image, 150, 100))
        #expect(try !isBlack(image, 450, 300))
        #expect(try !isBlack(image, 150, 300))
    }

    @Test func rotated180() async throws {
        let image = try await render(rotation: 180)
        #expect((image.width, image.height) == (400, 600))
        #expect(try isBlack(image, 300, 450))
        #expect(try !isBlack(image, 100, 150))
    }

    @Test func rotated270() async throws {
        let image = try await render(rotation: 270)
        #expect((image.width, image.height) == (600, 400))
        // Counter-clockwise rotation moves the top-left quarter to the bottom-left.
        #expect(try isBlack(image, 150, 300))
        #expect(try !isBlack(image, 450, 300))
        #expect(try !isBlack(image, 150, 100))
        #expect(try !isBlack(image, 450, 100))
    }

    private func makeDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("DroplimePDF-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makePDF(pages: Int, in dir: URL, options: [PDFDocumentWriteOption: Any] = [:]) throws -> URL {
        let document = PDFDocument()
        for index in 0..<pages {
            let page = try #require(PDFPage(image: NSImage(size: NSSize(width: 50, height: 50), flipped: false) { rect in
                NSColor.black.setFill()
                rect.fill()
                return true
            }))
            document.insert(page, at: index)
        }
        let url = dir.appendingPathComponent("doc.pdf")
        #expect(document.write(to: url, withOptions: options))
        return url
    }

    private func files(in dir: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
    }

    @Test(arguments: [Format.png, .jpg, .txt]) func lockedPDFThrowsAndLeavesNoOutput(format: Format) async throws {
        let dir = try makeDir()
        let pdf = try makePDF(pages: 2, in: dir, options: [.userPasswordOption: "secret", .ownerPasswordOption: "owner"])
        let output = dir.appendingPathComponent("out.\(format.ext)")
        await #expect(throws: ConversionError.self) {
            try await PDFConverter().convert(pdf, to: format, output: output)
        }
        #expect(try files(in: dir) == ["doc.pdf"])
    }

    @Test func emptyPDFThrows() async throws {
        let dir = try makeDir()
        let pdf = dir.appendingPathComponent("empty.pdf")
        // PDFKit refuses to write a document without pages, so this is a hand-written PDF with an empty page tree
        // (PDFKit may refuse to open it at all, which is a failure as well).
        var body = "%PDF-1.4\n"
        var offsets: [Int] = []
        for object in ["<</Type/Catalog/Pages 2 0 R>>", "<</Type/Pages/Kids[]/Count 0>>"] {
            offsets.append(body.utf8.count)
            body += "\(offsets.count) 0 obj\(object)endobj\n"
        }
        let xref = body.utf8.count
        body += "xref\n0 3\n0000000000 65535 f \n"
        body += offsets.map { String(format: "%010d 00000 n \n", $0) }.joined()
        body += "trailer<</Size 3/Root 1 0 R>>\nstartxref\n\(xref)\n%%EOF\n"
        try Data(body.utf8).write(to: pdf)
        let output = dir.appendingPathComponent("out.png")
        await #expect(throws: ConversionError.self) {
            try await PDFConverter().convert(pdf, to: .png, output: output)
        }
        #expect(try files(in: dir) == ["empty.pdf"])
    }

    @Test func multiPageNeverOverwritesExistingFile() async throws {
        let dir = try makeDir()
        let pdf = try makePDF(pages: 2, in: dir)
        let existing = dir.appendingPathComponent("doc\(L.pageSuffix(1)).png")
        try Data("keep".utf8).write(to: existing)
        try await PDFConverter().convert(pdf, to: .png, output: dir.appendingPathComponent("doc.png"))
        #expect(try Data(contentsOf: existing) == Data("keep".utf8))
        #expect(try files(in: dir).count == 4) // doc.pdf, kept page 1, "page 1 2", page 2
    }

    @Test func cancellationRemovesWrittenPages() async throws {
        let dir = try makeDir()
        let pdf = try makePDF(pages: 3, in: dir)
        let output = dir.appendingPathComponent("doc.png")
        // The quality closure runs once per page, so cancelling inside it stops the run after the first page was written.
        let task = Task {
            let calls = OSAllocatedUnfairLock(initialState: 0)
            let converter = PDFConverter(quality: {
                if calls.withLock({ $0 += 1; return $0 }) == 2 { withUnsafeCurrentTask { $0?.cancel() } }
                return 0.9
            })
            try await converter.convert(pdf, to: .png, output: output)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try files(in: dir) == ["doc.pdf"])
    }
}
