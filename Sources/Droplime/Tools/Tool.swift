import Foundation
import UniformTypeIdentifiers

/// A tool in the Cmd wheel. Tools always create new files and leave the originals untouched.
protocol Tool {
    var label: String { get }
    /// Whether the tool fits exactly this selection (types in file order).
    func applies(to types: [UTType]) -> Bool
    /// Runs the tool and returns the files it created.
    func run(_ urls: [URL]) async throws -> [URL]
}

extension Tool {
    /// For tools that process each file on its own.
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
        tools(forTypes: ConversionService.types(of: urls))
    }

    /// Tools for files of the given types (in file order).
    func tools(forTypes types: [UTType]) -> [Tool] {
        guard !types.isEmpty else { return [] }
        return tools.filter { $0.applies(to: types) }
    }

    /// All tools, most important first.
    static func standard() -> ToolService {
        ToolService(tools: [
            ResizeImageTool(), RotateImageTool(), StripMetadataTool(),
            MergePDFTool(), SplitPDFTool(), CompressPDFTool(), RotatePDFTool(),
            CompressVideoTool(), RemoveAudioTool(), CompressAudioTool(),
            ZipTool(), UnzipTool(),
        ])
    }
}
