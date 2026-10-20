import AppKit
import UniformTypeIdentifiers

/// Text documents via the built-in `textutil`; PDF via AppKit printing.
struct DocumentConverter: Converter {
    /// Format → name textutil expects for `-convert`.
    private static let textutilFormats: [(Format, String)] = [
        (.docx, "docx"), (.rtf, "rtf"), (.html, "html"), (.txt, "txt"), (.odt, "odt"),
    ]
    private static let inputTypes = [
        "org.openxmlformats.wordprocessingml.document", "com.microsoft.word.doc", "org.oasis-open.opendocument.text",
        UTType.rtf.identifier, UTType.rtfd.identifier, UTType.html.identifier, UTType.plainText.identifier,
        UTType.webArchive.identifier,
    ]

    func targets(for type: UTType) -> [Format] {
        guard type.conforms(toAnyOf: Self.inputTypes) else { return [] }
        return Self.textutilFormats.map(\.0) + [.pdf]
    }

    func convert(_ input: URL, to format: Format, output: URL) async throws {
        if format == .pdf {
            try await Self.printToPDF(input, output: output)
            return
        }
        guard let name = Self.textutilFormats.first(where: { $0.0 == format })?.1 else {
            throw ConversionError(message: L.notSupported(format.label))
        }
        try await ExternalTool.run(URL(fileURLWithPath: "/usr/bin/textutil"),
                                   ["-convert", name, "-output", output.path, input.path])
    }

    /// Lays out the document on A4 pages and "prints" it to a PDF file.
    @MainActor
    private static func printToPDF(_ input: URL, output: URL) throws {
        let text = try NSAttributedString(url: input, options: [:], documentAttributes: nil)
        let paper = NSSize(width: 595, height: 842)
        let margin: CGFloat = 56

        let info = NSPrintInfo(dictionary: [
            .jobDisposition: NSPrintInfo.JobDisposition.save,
            .jobSavingURL: output,
        ])
        info.paperSize = paper
        info.topMargin = margin; info.bottomMargin = margin
        info.leftMargin = margin; info.rightMargin = margin
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: paper.width - 2 * margin, height: paper.height))
        textView.isVerticallyResizable = true
        textView.textStorage?.setAttributedString(text)
        textView.sizeToFit()

        let operation = NSPrintOperation(view: textView, printInfo: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        guard operation.run() else { throw ConversionError(message: L.pdfFailed) }
    }
}
