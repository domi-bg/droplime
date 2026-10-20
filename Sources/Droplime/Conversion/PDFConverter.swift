import AppKit
import PDFKit
import UniformTypeIdentifiers

/// PDF → images (one file per page) or text.
struct PDFConverter: Converter {
    func targets(for type: UTType) -> [Format] {
        type.conforms(to: .pdf) ? [.png, .jpg, .txt] : []
    }

    func convert(_ input: URL, to format: Format, output: URL) async throws {
        guard let document = PDFDocument(url: input) else {
            throw ConversionError(message: L.cannotOpen(input.lastPathComponent))
        }
        if format == .txt {
            guard let text = document.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ConversionError(message: L.noText(input.lastPathComponent))
            }
            try text.write(to: output, atomically: true, encoding: .utf8)
            return
        }
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let url = document.pageCount == 1
                ? output
                : ConversionService.outputURL(for: input, ext: format.ext, suffix: L.pageSuffix(index + 1))
            try Self.render(page, as: format, to: url)
        }
    }

    /// Renders at 144 dpi (twice the PDF resolution) on a white background.
    private static func render(_ page: PDFPage, as format: Format, to url: URL) throws {
        let scale: CGFloat = 2
        let bounds = page.bounds(for: .mediaBox)
        let width = Int(bounds.width * scale), height = Int(bounds.height * scale)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw ConversionError(message: L.pageFailed) }
        context.setFillColor(.white)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        guard let image = context.makeImage(), let type = format.type,
              let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)
        else { throw ConversionError(message: L.pageFailed) }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ConversionError(message: L.pageFailed) }
    }
}
