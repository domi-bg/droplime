import Foundation

/// Finds and runs command line tools such as ffmpeg, soffice or pandoc.
enum ExternalTool {
    static let searchPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]

    static func find(_ name: String, extraPaths: [String] = []) -> URL? {
        (extraPaths + searchPaths)
            .map { URL(fileURLWithPath: $0).appendingPathComponent(name) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// Runs the tool and returns stdout; throws on a non-zero exit code.
    /// Output goes to temp files so full pipes can't block the process.
    @discardableResult
    static func run(_ executable: URL, _ arguments: [String]) async throws -> String {
        let temp = FileManager.default.temporaryDirectory
        let outURL = temp.appendingPathComponent(UUID().uuidString)
        let errURL = temp.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: outURL.path, contents: nil)
        FileManager.default.createFile(atPath: errURL.path, contents: nil)
        defer {
            try? FileManager.default.removeItem(at: outURL)
            try? FileManager.default.removeItem(at: errURL)
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = try FileHandle(forWritingTo: outURL)
        process.standardError = try FileHandle(forWritingTo: errURL)

        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
        guard status == 0 else {
            let tail = ((try? String(contentsOf: errURL, encoding: .utf8)) ?? "")
                .split(separator: "\n").suffix(3).joined(separator: "\n")
            throw ConversionError(message: L.externalToolFailed(executable.lastPathComponent, tail))
        }
        return (try? String(contentsOf: outURL, encoding: .utf8)) ?? ""
    }
}
