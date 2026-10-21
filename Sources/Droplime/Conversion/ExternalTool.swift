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
    /// Honors task cancellation: the process is terminated and `CancellationError` is thrown.
    /// Output goes to temp files so full pipes can't block the process.
    @discardableResult
    static func run(_ executable: URL, _ arguments: [String], currentDirectory: URL? = nil) async throws -> String {
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
        process.currentDirectoryURL = currentDirectory
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = try FileHandle(forWritingTo: outURL)
        process.standardError = try FileHandle(forWritingTo: errURL)

        let name = executable.lastPathComponent
        Log.tools.info("Running \(name, privacy: .public) \(arguments.joined(separator: " "))")
        let control = ProcessControl(process)
        let status: Int32 = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
                do { try control.launch() } catch { continuation.resume(throwing: error) }
            }
        } onCancel: {
            control.cancel()
        }
        // A process terminated because of the cancellation is not a tool failure.
        if control.isCancelled {
            Log.tools.info("\(name, privacy: .public) cancelled")
            throw CancellationError()
        }
        guard status == 0 else {
            let tail = ((try? String(contentsOf: errURL, encoding: .utf8)) ?? "")
                .split(separator: "\n").suffix(3).joined(separator: "\n")
            Log.tools.error("\(name, privacy: .public) exited with \(status): \(tail, privacy: .public)")
            throw ConversionError(message: L.externalToolFailed(name, tail))
        }
        Log.tools.info("\(name, privacy: .public) finished")
        return (try? String(contentsOf: outURL, encoding: .utf8)) ?? ""
    }
}

/// Launches and cancels a process without races: a cancel before the launch prevents it,
/// a cancel after the launch terminates the process.
private final class ProcessControl: @unchecked Sendable {
    private let process: Process
    private let lock = NSLock()
    private var launched = false
    private var cancelled = false

    init(_ process: Process) {
        self.process = process
    }

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }

    func launch() throws {
        lock.lock(); defer { lock.unlock() }
        if cancelled { throw CancellationError() }
        try process.run()
        launched = true
    }

    func cancel() {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
        guard launched, process.isRunning else { return }
        process.terminate()
        // A hung process may ignore SIGTERM; kill it if it is still there after two seconds.
        let process = process
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }
}
