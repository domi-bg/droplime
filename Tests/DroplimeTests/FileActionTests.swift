import Foundation
import Testing
@testable import Droplime

struct FileActionTests {
    let root: URL
    let source: URL
    let target: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("DroplimeActions-\(UUID().uuidString)")
        source = root.appendingPathComponent("quelle", isDirectory: true)
        target = root.appendingPathComponent("ziel", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    }

    private func file(_ name: String, in folder: URL? = nil) throws -> URL {
        let url = (folder ?? source).appendingPathComponent(name)
        try Data(name.utf8).write(to: url)
        return url
    }

    @Test func copyKeepsOriginalAndAvoidsOverwriting() throws {
        let original = try file("bericht.pdf")
        _ = try file("bericht.pdf", in: target)

        let copies = try FileAction.copy([original], to: target)

        #expect(copies.map(\.lastPathComponent) == ["bericht 2.pdf"])
        #expect(FileManager.default.fileExists(atPath: original.path))
        #expect(try String(contentsOf: target.appendingPathComponent("bericht.pdf"), encoding: .utf8) == "bericht.pdf")
    }

    @Test func copyWorksWithFolders() throws {
        let folder = source.appendingPathComponent("Fotos", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        _ = try file("a.jpg", in: folder)

        try FileAction.copy([folder], to: target)

        #expect(FileManager.default.fileExists(atPath: target.appendingPathComponent("Fotos/a.jpg").path))
    }

    @Test func moveRemovesOriginalAndSkipsSameFolder() throws {
        let a = try file("a.txt"), b = try file("b.txt", in: target)

        let moved = try FileAction.move([a, b], to: target)

        #expect(moved.map(\.lastPathComponent) == ["a.txt"])
        #expect(!FileManager.default.fileExists(atPath: a.path))
        #expect(FileManager.default.fileExists(atPath: b.path))
    }

    @Test func pathTextAndTerminalFolders() throws {
        let a = try file("a.txt"), b = try file("b.txt")

        #expect(FileAction.pathText([a, b]) == "\(a.path)\n\(b.path)")
        #expect(FileAction.folders(of: [a, b, target]).map(\.lastPathComponent) == ["quelle", "ziel"])
    }
}
