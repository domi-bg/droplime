import AppKit
import PDFKit
import UniformTypeIdentifiers

private func open(_ url: URL) throws -> PDFDocument {
    guard let document = PDFDocument(url: url) else {
        throw ConversionError(message: "\(url.lastPathComponent) konnte nicht geöffnet werden.")
    }
    return document
}

private func save(_ document: PDFDocument, to url: URL, options: [PDFDocumentWriteOption: Any] = [:]) throws {
    guard document.write(to: url, withOptions: options) else {
        throw ConversionError(message: "\(url.lastPathComponent) konnte nicht geschrieben werden.")
    }
}

/// Fügt mehrere PDFs und Bilder in Reihenfolge zu einem PDF zusammen.
struct MergePDFTool: Tool {
    let label = "Zusammenfügen"

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
                    throw ConversionError(message: "\(url.lastPathComponent) konnte nicht gelesen werden.")
                }
                merged.insert(page, at: merged.pageCount)
            }
        }
        let output = FileAction.uniqueDestination(for: URL(fileURLWithPath: "Zusammengefügt.pdf"),
                                                  in: urls[0].deletingLastPathComponent())
        try save(merged, to: output)
        return [output]
    }
}

/// Teilt ein PDF in einzelne Seiten.
struct SplitPDFTool: Tool {
    let label = "Teilen"

    func applies(to types: [UTType]) -> Bool { types.allSatisfy { $0.conforms(to: .pdf) } }

    func run(_ urls: [URL]) async throws -> [URL] {
        var outputs: [URL] = []
        for url in urls {
            let document = try open(url)
            guard document.pageCount > 1 else {
                throw ConversionError(message: "\(url.lastPathComponent) hat nur eine Seite.")
            }
            for i in 0..<document.pageCount {
                guard let page = document.page(at: i)?.copy() as? PDFPage else { continue }
                let single = PDFDocument()
                single.insert(page, at: 0)
                let output = ConversionService.outputURL(for: url, ext: "pdf", suffix: " – Seite \(i + 1)")
                try save(single, to: output)
                outputs.append(output)
            }
        }
        return outputs
    }
}

/// Verkleinert eingebettete Bilder (JPEG, Bildschirmauflösung).
struct CompressPDFTool: Tool {
    let label = "Komprimieren"

    func applies(to types: [UTType]) -> Bool { types.allSatisfy { $0.conforms(to: .pdf) } }

    func run(_ urls: [URL]) async throws -> [URL] {
        try await eachFile(urls) { url in
            let output = ConversionService.outputURL(for: url, ext: "pdf", suffix: " (komprimiert)")
            try save(try open(url), to: output, options: [.saveImagesAsJPEGOption: true, .optimizeImagesForScreenOption: true])
            return output
        }
    }
}

/// Dreht alle Seiten um 90° im Uhrzeigersinn.
struct RotatePDFTool: Tool {
    let label = "Drehen"

    func applies(to types: [UTType]) -> Bool { types.allSatisfy { $0.conforms(to: .pdf) } }

    func run(_ urls: [URL]) async throws -> [URL] {
        try await eachFile(urls) { url in
            let document = try open(url)
            for i in 0..<document.pageCount {
                if let page = document.page(at: i) { page.rotation = (page.rotation + 90) % 360 }
            }
            let output = ConversionService.outputURL(for: url, ext: "pdf", suffix: " (gedreht)")
            try save(document, to: output)
            return output
        }
    }
}
