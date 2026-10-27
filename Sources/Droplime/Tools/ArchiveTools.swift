import Foundation
import UniformTypeIdentifiers

private let ditto = URL(fileURLWithPath: "/usr/bin/ditto")
private let zip = URL(fileURLWithPath: "/usr/bin/zip")

/// Packs files and folders into a ZIP, like "Compress" in Finder.
struct ZipTool: Tool {
    var label: String { L.toolZip }

    func applies(to types: [UTType]) -> Bool { !types.allSatisfy { $0.conforms(to: .zip) } }

    func run(_ urls: [URL]) async throws -> [URL] {
        let folder = urls[0].deletingLastPathComponent()
        if urls.count == 1 {
            let output = FileAction.uniqueDestination(
                for: URL(fileURLWithPath: urls[0].lastPathComponent).appendingPathExtension("zip"), in: folder)
            try await removingOutputOnFailure(output) {
                try await ExternalTool.run(ditto, ["-c", "-k", "--sequesterRsrc", "--keepParent", urls[0].path, output.path])
            }
            return [output]
        }
        let output = FileAction.uniqueDestination(for: URL(fileURLWithPath: L.archiveFileName + ".zip"), in: folder)
        if urls.allSatisfy({ $0.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL }) {
            // Same parent folder: zip the items by relative name, no copying needed.
            // "--" ends the options, so a file named like "-m" is archived instead of read as a flag.
            try await removingOutputOnFailure(output) {
                try await ExternalTool.run(zip, ["-r", "-y", "-X", output.path, "--"] + urls.map(\.lastPathComponent),
                                           currentDirectory: folder)
            }
            return [output]
        }
        // Items from different folders: copy into a temp folder and zip its contents.
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        try FileAction.copy(urls, to: temp)
        try await removingOutputOnFailure(output) {
            try await ExternalTool.run(ditto, ["-c", "-k", "--sequesterRsrc", temp.path, output.path])
        }
        return [output]
    }
}

/// Unzips ZIP files into a folder next to them.
struct UnzipTool: Tool {
    var label: String { L.toolUnzip }

    func applies(to types: [UTType]) -> Bool { types.allSatisfy { $0.conforms(to: .zip) } }

    func run(_ urls: [URL]) async throws -> [URL] {
        try await eachFile(urls) { url in
            let output = FileAction.uniqueDestination(
                for: url.deletingPathExtension(), in: url.deletingLastPathComponent())
            try await removingOutputOnFailure(output) {
                try await ExternalTool.run(ditto, ["-x", "-k", url.path, output.path])
            }
            return output
        }
    }
}
