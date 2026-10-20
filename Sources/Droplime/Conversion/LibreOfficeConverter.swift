import Foundation
import UniformTypeIdentifiers

/// Optional: Office-Dokumente über LibreOffice im Hintergrund. Braucht LibreOffice in /Applications.
struct LibreOfficeConverter: Converter {
    let executable: URL

    private static let text = ["org.openxmlformats.wordprocessingml.document", "com.microsoft.word.doc",
                               "org.oasis-open.opendocument.text", "public.rtf"]
    private static let sheets = ["org.openxmlformats.spreadsheetml.sheet", "com.microsoft.excel.xls",
                                 "org.oasis-open.opendocument.spreadsheet", "public.comma-separated-values-text"]
    private static let slides = ["org.openxmlformats.presentationml.presentation", "com.microsoft.powerpoint.ppt",
                                 "org.oasis-open.opendocument.presentation"]

    init?() {
        guard let executable = ExternalTool.find("soffice", extraPaths: ["/Applications/LibreOffice.app/Contents/MacOS"])
        else { return nil }
        self.executable = executable
    }

    func targets(for type: UTType) -> [Format] {
        if type.conforms(toAnyOf: Self.text) { return [.pdf, .docx, .odt] }
        if type.conforms(toAnyOf: Self.sheets) { return [.pdf, .xlsx, .csv, .ods] }
        if type.conforms(toAnyOf: Self.slides) { return [.pdf, .pptx] }
        return []
    }

    /// soffice schreibt immer "<Name>.<ext>" in einen Ordner; daher erst in einen Temp-Ordner, dann verschieben.
    func convert(_ input: URL, to format: Format, output: URL) async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        try await ExternalTool.run(executable, ["--headless", "--convert-to", format.ext, "--outdir", temp.path, input.path])
        let result = temp.appendingPathComponent(input.deletingPathExtension().lastPathComponent).appendingPathExtension(format.ext)
        try FileManager.default.moveItem(at: result, to: output)
    }
}
