import Foundation
import os

/// Loggers; view with `log stream --predicate 'subsystem == "app.droplime.Droplime"'`.
enum Log {
    static let jobs = Logger(subsystem: "app.droplime.Droplime", category: "jobs")
    static let tools = Logger(subsystem: "app.droplime.Droplime", category: "tools")
}

/// A unit of work after a drop: a conversion or a tool run.
struct Job {
    /// For the log, e.g. "3 files → PDF".
    let title: String
    let fileCount: Int
    /// How many jobs may run at the same time while this one runs; 1 = alone.
    /// Only jobs that all allow it run side by side (image and PDF conversions).
    let concurrency: Int
    /// The work. Throws `CancellationError` when cancelled; reports other errors itself.
    let run: @MainActor () async throws -> Void

    init(title: String, fileCount: Int, concurrency: Int = 1, run: @escaping @MainActor () async throws -> Void) {
        self.title = title
        self.fileCount = fileCount
        self.concurrency = max(concurrency, 1)
        self.run = run
    }
}

/// Runs jobs in order: serial jobs one after another (so e.g. LibreOffice never runs twice at once),
/// concurrent jobs side by side up to their limit. Jobs never overtake each other.
@MainActor
final class JobQueue: ObservableObject {
    /// Number of files in running jobs.
    @Published private(set) var running = 0
    /// Number of files in jobs that wait for their turn.
    @Published private(set) var pending = 0

    private var waiting: [Job] = []
    private var active: [UUID: (job: Job, task: Task<Void, Never>)] = [:]

    var isIdle: Bool { waiting.isEmpty && active.isEmpty }

    func enqueue(_ job: Job) {
        waiting.append(job)
        Log.jobs.info("Queued: \(job.title, privacy: .public)")
        startNext()
    }

    /// Drops waiting jobs and cancels running ones.
    func cancelAll() {
        guard !isIdle else { return }
        Log.jobs.info("Cancelling \(self.active.count) running and \(self.waiting.count) waiting job(s)")
        waiting.removeAll()
        for entry in active.values { entry.task.cancel() }
        updateCounts()
    }

    private func canStart(_ job: Job) -> Bool {
        if active.isEmpty { return true }
        return job.concurrency > 1 && active.count < job.concurrency
            && active.values.allSatisfy { $0.job.concurrency > 1 }
    }

    private func startNext() {
        while let job = waiting.first, canStart(job) {
            waiting.removeFirst()
            let id = UUID()
            let task = Task { [weak self] in
                await Self.execute(job)
                self?.finished(id)
            }
            active[id] = (job, task)
        }
        updateCounts()
    }

    private func finished(_ id: UUID) {
        active[id] = nil
        startNext()
    }

    private func updateCounts() {
        let running = active.values.reduce(0) { $0 + $1.job.fileCount }
        let pending = waiting.reduce(0) { $0 + $1.fileCount }
        if self.running != running { self.running = running }
        if self.pending != pending { self.pending = pending }
    }

    private static func execute(_ job: Job) async {
        let start = Date()
        Log.jobs.info("Started: \(job.title, privacy: .public)")
        do {
            try await job.run()
            let seconds = Date().timeIntervalSince(start)
            Log.jobs.info("Finished: \(job.title, privacy: .public) in \(seconds, format: .fixed(precision: 1)) s")
        } catch is CancellationError {
            Log.jobs.info("Cancelled: \(job.title, privacy: .public)")
        } catch {
            Log.jobs.error("Failed: \(job.title, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
