import Foundation
import UniformTypeIdentifiers

/// Optional: Markdown and e-books via Pandoc. Needs `brew install pandoc`.
struct PandocConverter: Converter {
    let executable: URL

    private static let markdown = "net.daringfireball.markdown"
    private static let others = ["org.openxmlformats.wordprocessingml.document", "public.html",
                                 "org.oasis-open.opendocument.text", "org.idpf.epub-container"]

    init?() {
        guard let executable = ExternalTool.find("pandoc") else { return nil }
        self.executable = executable
    }

    func targets(for type: UTType) -> [Format] {
        if type.conforms(toAnyOf: [Self.markdown]) || type.preferredFilenameExtension == "md" {
            return [.docx, .html, .epub, .odt]
        }
        if type.conforms(toAnyOf: Self.others) { return [.md, .epub] }
        return []
    }

    func convert(_ input: URL, to format: Format, output: URL) async throws {
        try await ExternalTool.run(executable, ["--standalone", "-o", output.path, input.path])
    }
}
