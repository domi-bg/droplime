import Foundation
import Testing
@testable import Droplime

@MainActor
struct JobQueueTests {
    /// Records events from jobs; jobs run on the main actor.
    final class Events {
        var list: [String] = []
        func index(_ event: String) -> Int? { list.firstIndex(of: event) }
    }

    private func waitUntilIdle(_ queue: JobQueue, timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !queue.isIdle {
            #expect(Date() < deadline, "Queue didn't finish in time")
            if Date() >= deadline { return }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private func job(_ name: String, events: Events, concurrency: Int = 1, seconds: Double) -> Job {
        Job(title: name, fileCount: 1, concurrency: concurrency) {
            events.list.append("\(name) start")
            try await Task.sleep(for: .seconds(seconds))
            events.list.append("\(name) end")
        }
    }

    @Test func serialJobsRunOneAfterAnother() async throws {
        let queue = JobQueue(), events = Events()
        queue.enqueue(job("A", events: events, seconds: 0.3))
        queue.enqueue(job("B", events: events, seconds: 0.01))
        #expect(queue.running == 1)
        #expect(queue.pending == 1)
        try await waitUntilIdle(queue)
        #expect(events.list == ["A start", "A end", "B start", "B end"])
        #expect(queue.running == 0 && queue.pending == 0)
    }

    @Test func concurrentJobsRunInParallel() async throws {
        let queue = JobQueue(), events = Events()
        queue.enqueue(job("A", events: events, concurrency: 4, seconds: 0.3))
        queue.enqueue(job("B", events: events, concurrency: 4, seconds: 0.01))
        #expect(queue.running == 2)
        try await waitUntilIdle(queue)
        let bStart = try #require(events.index("B start")), aEnd = try #require(events.index("A end"))
        #expect(bStart < aEnd)
    }

    @Test func serialJobWaitsForConcurrentOnes() async throws {
        let queue = JobQueue(), events = Events()
        queue.enqueue(job("A", events: events, concurrency: 4, seconds: 0.2))
        queue.enqueue(job("B", events: events, seconds: 0.01))
        queue.enqueue(job("C", events: events, concurrency: 4, seconds: 0.01))
        try await waitUntilIdle(queue)
        #expect(events.list == ["A start", "A end", "B start", "B end", "C start", "C end"])
    }

    @Test func cancelAllCancelsRunningAndDropsWaitingJobs() async throws {
        let queue = JobQueue(), events = Events()
        queue.enqueue(Job(title: "long", fileCount: 3) {
            events.list.append("long start")
            do {
                try await Task.sleep(for: .seconds(30))
                events.list.append("long end")
            } catch {
                events.list.append(error is CancellationError ? "long cancelled" : "long failed")
                throw error
            }
        })
        queue.enqueue(job("next", events: events, seconds: 0.01))
        #expect(queue.running == 3 && queue.pending == 1)
        try await Task.sleep(for: .milliseconds(100))

        let start = Date()
        queue.cancelAll()
        #expect(queue.pending == 0)
        try await waitUntilIdle(queue, timeout: 2)
        #expect(Date().timeIntervalSince(start) < 1)
        #expect(events.list == ["long start", "long cancelled"])
        #expect(queue.running == 0)
    }
}

struct ExternalToolCancellationTests {
    @Test func cancelTerminatesTheProcess() async throws {
        let start = Date()
        let task = Task { try await ExternalTool.run(URL(fileURLWithPath: "/bin/sleep"), ["30"]) }
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(Date().timeIntervalSince(start) < 1.2)
    }

    @Test func cancelBeforeLaunchDoesNotRunTheTool() async throws {
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("DroplimeMarker-\(UUID().uuidString)")
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await ExternalTool.run(URL(fileURLWithPath: "/usr/bin/touch"), [marker.path])
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }

    @Test func failuresAreStillToolErrors() async throws {
        await #expect(throws: ConversionError.self) {
            try await ExternalTool.run(URL(fileURLWithPath: "/bin/sh"), ["-c", "echo broken >&2; exit 3"])
        }
    }
}
