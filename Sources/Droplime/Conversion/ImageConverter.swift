import AppKit
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// Images via ImageIO. Only offers formats ImageIO can write on this system.
struct ImageConverter: Converter {
    private static let writable = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
    private static let candidates: [Format] = [.png, .jpg, .heic, .tiff, .webp, .gif, .bmp, .avif]

    var concurrent: Bool { true }

    func targets(for type: UTType) -> [Format] {
        guard type.conforms(to: .image) else { return [] }
        let formats = Self.candidates.filter { $0.type.map { Self.writable.contains($0.identifier) } ?? false }
        return formats + [.pdf]
    }

    /// Formats that carry EXIF/orientation; these are copied from the source so the metadata survives.
    private static let metadataFormats: [Format] = [.jpg, .heic, .tiff, .png, .webp, .avif]

    func convert(_ input: URL, to format: Format, output: URL) async throws {
        if format == .pdf {
            let image = try Self.upright(input)
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
        if Self.metadataFormats.contains(format), let source = CGImageSourceCreateWithURL(input as CFURL, nil),
           CGImageSourceGetCount(source) > 0 {
            CGImageDestinationAddImageFromSource(destination, source, 0, options)
        } else {
            CGImageDestinationAddImage(destination, try Self.upright(input), options)
        }
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError(message: L.cannotWrite(format.label))
        }
    }

    /// Pixels with the EXIF orientation applied; NSImage fallback (e.g. SVG) when ImageIO cannot read the file.
    private static func upright(_ url: URL) throws -> CGImage {
        if let (image, _) = try? uprightImage(url) { return image }
        return try loadImage(url)
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
