import AppKit
import PDFKit
import UniformTypeIdentifiers

private func open(_ url: URL) throws -> PDFDocument {
    guard let document = PDFDocument(url: url) else {
        throw ConversionError(message: L.cannotOpen(url.lastPathComponent))
    }
    return document
}

private func save(_ document: PDFDocument, to url: URL, options: [PDFDocumentWriteOption: Any] = [:]) throws {
    guard document.write(to: url, withOptions: options) else {
        throw ConversionError(message: L.cannotWrite(url.lastPathComponent))
    }
}

/// Merges several PDFs and images, in order, into one PDF.
struct MergePDFTool: Tool {
    var label: String { L.toolMerge }

    func applies(to types: [UTType]) -> Bool {
        types.count >= 2 && types.contains { $0.conforms(to: .pdf) || $0.conforms(to: .image) }
            && types.allSatisfy { $0.conforms(to: .pdf) || $0.conforms(to: .image) }
    }

    func run(_ urls: [URL]) async throws -> [URL] {
        let merged = PDFDocument()
        for url in urls {
            if ConversionService.type(of: url)?.conforms(to: .pdf) == true {
                let document = try open(url)
                for i in 0..<document.pageCount {
                    if let page = document.page(at: i)?.copy() as? PDFPage { merged.insert(page, at: merged.pageCount) }
                }
            } else {
                guard let image = NSImage(contentsOf: url), let page = PDFPage(image: image) else {
                    throw ConversionError(message: L.cannotRead(url.lastPathComponent))
                }
                merged.insert(page, at: merged.pageCount)
            }
        }
        let output = FileAction.uniqueDestination(for: URL(fileURLWithPath: L.mergedFileName + ".pdf"),
                                                  in: urls[0].deletingLastPathComponent())
        try save(merged, to: output)
        return [output]
    }
}

/// Splits a PDF into single pages.
struct SplitPDFTool: Tool {
    var label: String { L.toolSplit }

    func applies(to types: [UTType]) -> Bool { types.allSatisfy { $0.conforms(to: .pdf) } }

    func run(_ urls: [URL]) async throws -> [URL] {
        var outputs: [URL] = []
        for url in urls {
            let document = try open(url)
            guard document.pageCount > 1 else {
                throw ConversionError(message: L.onlyOnePage(url.lastPathComponent))
            }
            for i in 0..<document.pageCount {
                guard let page = document.page(at: i)?.copy() as? PDFPage else { continue }
                let single = PDFDocument()
                single.insert(page, at: 0)
                let output = ConversionService.outputURL(for: url, ext: "pdf", suffix: L.pageSuffix(i + 1))
                try save(single, to: output)
                outputs.append(output)
            }
        }
        return outputs
    }
}

/// Downsamples embedded images (JPEG, screen resolution).
struct CompressPDFTool: Tool {
    var label: String { L.toolCompress }

    func applies(to types: [UTType]) -> Bool { types.allSatisfy { $0.conforms(to: .pdf) } }

    func run(_ urls: [URL]) async throws -> [URL] {
        try await eachFile(urls) { url in
            let output = ConversionService.outputURL(for: url, ext: "pdf", suffix: L.suffixCompressed)
            try save(try open(url), to: output, options: [.saveImagesAsJPEGOption: true, .optimizeImagesForScreenOption: true])
            return output
        }
    }
}

/// Rotates all pages by 90° clockwise.
struct RotatePDFTool: Tool {
    var label: String { L.toolRotate }

    func applies(to types: [UTType]) -> Bool { types.allSatisfy { $0.conforms(to: .pdf) } }

    func run(_ urls: [URL]) async throws -> [URL] {
        try await eachFile(urls) { url in
            let document = try open(url)
            for i in 0..<document.pageCount {
                if let page = document.page(at: i) { page.rotation = (page.rotation + 90) % 360 }
            }
            let output = ConversionService.outputURL(for: url, ext: "pdf", suffix: L.suffixRotated)
            try save(document, to: output)
            return output
        }
    }
}
