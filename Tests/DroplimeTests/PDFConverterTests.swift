import AppKit
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
}
