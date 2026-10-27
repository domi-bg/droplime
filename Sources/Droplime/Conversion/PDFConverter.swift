import AppKit
import PDFKit
import UniformTypeIdentifiers

/// PDF → images (one file per page) or text.
struct PDFConverter: Converter {
    /// JPEG quality, 0 to 1. A closure, so a changed setting applies to the next conversion.
    let quality: @Sendable () -> Double

    init(quality: @escaping @Sendable () -> Double = { 0.9 }) {
        self.quality = quality
    }

    var concurrent: Bool { true }

    func targets(for type: UTType) -> [Format] {
        type.conforms(to: .pdf) ? [.png, .jpg, .txt] : []
    }

    func convert(_ input: URL, to format: Format, output: URL) async throws {
        guard let document = PDFDocument(url: input) else {
            throw ConversionError(message: L.cannotOpen(input.lastPathComponent))
        }
        if document.isLocked { throw ConversionError(message: L.pdfLocked(input.lastPathComponent)) }
        guard document.pageCount > 0 else { throw ConversionError(message: L.cannotOpen(input.lastPathComponent)) }
        if format == .txt {
            guard let text = document.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ConversionError(message: L.noText(input.lastPathComponent))
            }
            try text.write(to: output, atomically: true, encoding: .utf8)
            return
        }
        if document.pageCount == 1 {
            try Task.checkCancellation()
            try Self.render(document.page(at: 0), as: format, to: output, quality: quality())
            return
        }
        // Each page name is reserved like a single output; on failure or cancellation the pages written so far are removed.
        var reserved: [URL] = []
        defer { reserved.forEach { ConversionService.releaseOutputURL($0) } }
        do {
            for index in 0..<document.pageCount {
                try Task.checkCancellation()
                let url = ConversionService.reserveOutputURL(for: input, ext: format.ext, suffix: L.pageSuffix(index + 1))
                reserved.append(url)
                try Self.render(document.page(at: index), as: format, to: url, quality: quality())
            }
        } catch {
            reserved.forEach { try? FileManager.default.removeItem(at: $0) }
            throw error
        }
    }

    /// Renders at 144 dpi (twice the PDF resolution) on a white background.
    private static func render(_ page: PDFPage?, as format: Format, to url: URL, quality: Double) throws {
        guard let page else { throw ConversionError(message: L.pageFailed) }
        let scale: CGFloat = 2
        let bounds = page.bounds(for: .cropBox)
        let sideways = page.rotation % 180 != 0
        let width = Int((sideways ? bounds.height : bounds.width) * scale)
        let height = Int((sideways ? bounds.width : bounds.height) * scale)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw ConversionError(message: L.pageFailed) }
        context.setFillColor(.white)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .cropBox, to: context)
        guard let image = context.makeImage(), let type = format.type,
              let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)
        else { throw ConversionError(message: L.pageFailed) }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ConversionError(message: L.pageFailed) }
    }
}
