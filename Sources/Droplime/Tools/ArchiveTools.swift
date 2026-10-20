import Foundation
import UniformTypeIdentifiers

private let ditto = URL(fileURLWithPath: "/usr/bin/ditto")

/// Packt Dateien und Ordner in ein ZIP – wie „Komprimieren“ im Finder.
struct ZipTool: Tool {
    var label: String { L.toolZip }

    func applies(to types: [UTType]) -> Bool { !types.allSatisfy { $0.conforms(to: .zip) } }

    func run(_ urls: [URL]) async throws -> [URL] {
        let folder = urls[0].deletingLastPathComponent()
        if urls.count == 1 {
            let output = FileAction.uniqueDestination(
                for: URL(fileURLWithPath: urls[0].lastPathComponent).appendingPathExtension("zip"), in: folder)
            try await ExternalTool.run(ditto, ["-c", "-k", "--sequesterRsrc", "--keepParent", urls[0].path, output.path])
            return [output]
        }
        // Mehrere Objekte: in einen Temp-Ordner kopieren und den Inhalt packen.
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        try FileAction.copy(urls, to: temp)
        let output = FileAction.uniqueDestination(for: URL(fileURLWithPath: L.archiveFileName + ".zip"), in: folder)
        try await ExternalTool.run(ditto, ["-c", "-k", "--sequesterRsrc", temp.path, output.path])
        return [output]
    }
}

/// Entpackt ZIP-Dateien in einen Ordner daneben.
struct UnzipTool: Tool {
    var label: String { L.toolUnzip }

    func applies(to types: [UTType]) -> Bool { types.allSatisfy { $0.conforms(to: .zip) } }

    func run(_ urls: [URL]) async throws -> [URL] {
        try await eachFile(urls) { url in
            let output = FileAction.uniqueDestination(
                for: url.deletingPathExtension(), in: url.deletingLastPathComponent())
            try await ExternalTool.run(ditto, ["-x", "-k", url.path, output.path])
            return output
        }
    }
}
