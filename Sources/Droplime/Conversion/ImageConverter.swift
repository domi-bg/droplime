import AppKit
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// Images via ImageIO. Only offers formats ImageIO can write on this system.
struct ImageConverter: Converter {
    private static let writable = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
    private static let candidates: [Format] = [.png, .jpg, .heic, .tiff, .webp, .gif, .bmp]

    func targets(for type: UTType) -> [Format] {
        guard type.conforms(to: .image) else { return [] }
        let formats = Self.candidates.filter { $0.type.map { Self.writable.contains($0.identifier) } ?? false }
        return formats + [.pdf]
    }

    func convert(_ input: URL, to format: Format, output: URL) async throws {
        let image = try Self.loadImage(input)
        if format == .pdf {
            guard let page = PDFPage(image: NSImage(cgImage: image, size: .zero)) else {
                throw ConversionError(message: L.pdfFailed)
            }
            let document = PDFDocument()
            document.insert(page, at: 0)
            guard document.write(to: output) else { throw ConversionError(message: L.pdfFailed) }
            return
        }
        guard let type = format.type,
              let destination = CGImageDestinationCreateWithURL(output as CFURL, type.identifier as CFString, 1, nil)
        else { throw ConversionError(message: L.notSupported(format.label)) }
        let options = [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError(message: L.cannotWrite(format.label))
        }
    }

    /// ImageIO first; NSImage as a fallback, e.g. for SVG.
    static func loadImage(_ url: URL) throws -> CGImage {
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            return image
        }
        if let image = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return image
        }
        throw ConversionError(message: L.cannotRead(url.lastPathComponent))
    }
}
