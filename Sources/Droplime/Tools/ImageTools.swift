import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Liest ein Bild mit angewendeter EXIF-Ausrichtung (wie es im Finder angezeigt wird).
private func uprightImage(_ url: URL, maxPixelSize: Int? = nil) throws -> (CGImage, CFString) {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let type = CGImageSourceGetType(source),
          let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = props[kCGImagePropertyPixelWidth] as? Int, let height = props[kCGImagePropertyPixelHeight] as? Int
    else { throw ConversionError(message: L.cannotRead(url.lastPathComponent)) }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize ?? max(width, height),
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
        throw ConversionError(message: L.cannotRead(url.lastPathComponent))
    }
    return (image, type)
}

private func write(_ image: CGImage, type: CFString, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type, 1, nil) else {
        throw ConversionError(message: L.cannotWrite(url.lastPathComponent))
    }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw ConversionError(message: L.cannotWrite(url.lastPathComponent))
    }
}

private func isRasterImage(_ type: UTType) -> Bool {
    type.conforms(to: .image) && !type.conforms(to: .svg) && !type.conforms(to: .pdf)
}

/// Halbiert die Kantenlänge.
struct ResizeImageTool: Tool {
    var label: String { L.toolResize }

    func applies(to types: [UTType]) -> Bool { types.allSatisfy(isRasterImage) }

    func run(_ urls: [URL]) async throws -> [URL] {
        try await eachFile(urls) { url in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = props[kCGImagePropertyPixelWidth] as? Int, let height = props[kCGImagePropertyPixelHeight] as? Int
            else { throw ConversionError(message: L.cannotRead(url.lastPathComponent)) }
            let (image, type) = try uprightImage(url, maxPixelSize: max(width, height) / 2)
            let output = ConversionService.outputURL(for: url, ext: url.pathExtension, suffix: L.suffixSmall)
            try write(image, type: type, to: output)
            return output
        }
    }
}

/// Dreht um 90° im Uhrzeigersinn.
struct RotateImageTool: Tool {
    var label: String { L.toolRotate }

    func applies(to types: [UTType]) -> Bool { types.allSatisfy(isRasterImage) }

    func run(_ urls: [URL]) async throws -> [URL] {
        try await eachFile(urls) { url in
            let (image, type) = try uprightImage(url)
            guard let context = CGContext(data: nil, width: image.height, height: image.width, bitsPerComponent: 8,
                                          bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { throw ConversionError(message: L.cannotRotate(url.lastPathComponent)) }
            // Im Uhrzeigersinn: nach unten verschieben, dann um -90° drehen.
            context.translateBy(x: 0, y: CGFloat(image.width))
            context.rotate(by: -.pi / 2)
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            guard let rotated = context.makeImage() else {
                throw ConversionError(message: L.cannotRotate(url.lastPathComponent))
            }
            let output = ConversionService.outputURL(for: url, ext: url.pathExtension, suffix: L.suffixRotated)
            try write(rotated, type: type, to: output)
            return output
        }
    }
}

/// Entfernt EXIF, GPS und andere Metadaten verlustfrei; nur die Ausrichtung bleibt erhalten.
struct StripMetadataTool: Tool {
    var label: String { L.toolStripMetadata }

    func applies(to types: [UTType]) -> Bool {
        types.allSatisfy { $0.conforms(to: .jpeg) || $0.conforms(to: .heic) || $0.conforms(to: .tiff) || $0.conforms(to: .png) }
    }

    func run(_ urls: [URL]) async throws -> [URL] {
        try await eachFile(urls) { url in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let type = CGImageSourceGetType(source)
            else { throw ConversionError(message: L.cannotRead(url.lastPathComponent)) }
            let output = ConversionService.outputURL(for: url, ext: url.pathExtension, suffix: L.suffixNoMetadata)
            guard let destination = CGImageDestinationCreateWithURL(output as CFURL, type, 1, nil) else {
                throw ConversionError(message: L.cannotWrite(output.lastPathComponent))
            }
            let metadata = CGImageMetadataCreateMutable()
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            if let orientation = props?[kCGImagePropertyOrientation] {
                CGImageMetadataSetValueMatchingImageProperty(metadata, kCGImagePropertyTIFFDictionary,
                                                             kCGImagePropertyOrientation, orientation as CFTypeRef)
            }
            let options: [CFString: Any] = [
                kCGImageDestinationMetadata: metadata,
                kCGImageDestinationMergeMetadata: false,
                kCGImageMetadataShouldExcludeGPS: true,
                kCGImageMetadataShouldExcludeXMP: true,
            ]
            var error: Unmanaged<CFError>?
            // Verlustfrei kopieren; klappt das beim Format nicht, neu schreiben ohne Metadaten.
            if !CGImageDestinationCopyImageSource(destination, source, options as CFDictionary, &error) {
                try? FileManager.default.removeItem(at: output)
                let (image, _) = try uprightImage(url)
                try write(image, type: type, to: output)
            }
            return output
        }
    }
}
