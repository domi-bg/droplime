import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Droplime

/// Wheel items computed from types alone, as for file promises (Mail, Photos, Safari).
struct TypeTargetsTests {
    let service = ConversionService(converters: [ImageConverter(), PDFConverter()])

    @Test func imageTypeOffersOtherFormats() {
        let targets = service.targets(forTypes: [.png])
        #expect(targets.contains(.jpg))
        #expect(targets.contains(.pdf))
        #expect(!targets.contains(.png))
    }

    @Test func severalTypesOfferOnlyCommonFormats() {
        // PNG → JPG, HEIC, TIFF, … PDF; PDF → PNG, JPG, TXT.
        #expect(service.targets(forTypes: [.png, .pdf]) == [.jpg])
    }

    @Test func noTypesOfferNothing() {
        #expect(service.targets(forTypes: []).isEmpty)
        #expect(ToolService.standard().tools(forTypes: []).isEmpty)
    }

    @Test func unknownIdentifierGivesNoTypes() {
        #expect(ConversionService.types(identifiers: ["public.jpeg", "public.png"]) == [.jpeg, .png])
        #expect(ConversionService.types(identifiers: ["public.jpeg", ""]).isEmpty)
    }

    @Test func toolsForTypeMatchToolsForFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DroplimeTypes-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("photo.jpg")
        let context = try #require(CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                             bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
        #expect(CGImageDestinationFinalize(destination))

        let tools = ToolService.standard()
        let fromFile = tools.tools(for: [url]).map(\.label)
        #expect(!fromFile.isEmpty)
        #expect(tools.tools(forTypes: [.jpeg]).map(\.label) == fromFile)
    }
}
