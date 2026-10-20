import Foundation
import UniformTypeIdentifiers

/// Ein Werkzeug im Cmd-Rad. Werkzeuge erzeugen immer neue Dateien und lassen die Originale unangetastet.
protocol Tool {
    var label: String { get }
    /// Ob das Werkzeug für genau diese Auswahl passt (Typen in Reihenfolge der Dateien).
    func applies(to types: [UTType]) -> Bool
    /// Führt das Werkzeug aus und gibt die erzeugten Dateien zurück.
    func run(_ urls: [URL]) async throws -> [URL]
}

extension Tool {
    /// Für Werkzeuge, die jede Datei einzeln bearbeiten.
    func eachFile(_ urls: [URL], _ body: (URL) async throws -> URL) async throws -> [URL] {
        var outputs: [URL] = []
        for url in urls { outputs.append(try await body(url)) }
        return outputs
    }
}

final class ToolService {
    let tools: [Tool]

    init(tools: [Tool]) {
        self.tools = tools
    }

    func tools(for urls: [URL]) -> [Tool] {
        let types = urls.compactMap(ConversionService.type(of:))
        guard !types.isEmpty, types.count == urls.count else { return [] }
        return tools.filter { $0.applies(to: types) }
    }

    /// Alle Werkzeuge in Reihenfolge der Wichtigkeit.
    static func standard() -> ToolService {
        ToolService(tools: [
            ResizeImageTool(), RotateImageTool(), StripMetadataTool(),
            MergePDFTool(), SplitPDFTool(), CompressPDFTool(), RotatePDFTool(),
            CompressVideoTool(), RemoveAudioTool(), CompressAudioTool(),
            ZipTool(), UnzipTool(),
        ])
    }
}
