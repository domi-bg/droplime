import Foundation
import os
import UniformTypeIdentifiers

/// A target format as shown in the wheel.
struct Format: Hashable {
    let label: String
    let ext: String

    var type: UTType? { UTType(filenameExtension: ext) }

    static let png = Format(label: "PNG", ext: "png")
    static let jpg = Format(label: "JPG", ext: "jpg")
    static let heic = Format(label: "HEIC", ext: "heic")
    static let tiff = Format(label: "TIFF", ext: "tiff")
    static let gif = Format(label: "GIF", ext: "gif")
    static let bmp = Format(label: "BMP", ext: "bmp")
    static let avif = Format(label: "AVIF", ext: "avif")
    static let webp = Format(label: "WebP", ext: "webp")
    static let pdf = Format(label: "PDF", ext: "pdf")
    static let txt = Format(label: "TXT", ext: "txt")
    static let rtf = Format(label: "RTF", ext: "rtf")
    static let html = Format(label: "HTML", ext: "html")
    static let docx = Format(label: "DOCX", ext: "docx")
    static let odt = Format(label: "ODT", ext: "odt")
    static let md = Format(label: "MD", ext: "md")
    static let epub = Format(label: "EPUB", ext: "epub")
    static let xlsx = Format(label: "XLSX", ext: "xlsx")
    static let csv = Format(label: "CSV", ext: "csv")
    static let ods = Format(label: "ODS", ext: "ods")
    static let pptx = Format(label: "PPTX", ext: "pptx")
    static let mp4 = Format(label: "MP4", ext: "mp4")
    static let mov = Format(label: "MOV", ext: "mov")
    static let mkv = Format(label: "MKV", ext: "mkv")
    static let webm = Format(label: "WebM", ext: "webm")
    static let m4a = Format(label: "M4A", ext: "m4a")
    static let mp3 = Format(label: "MP3", ext: "mp3")
    static let wav = Format(label: "WAV", ext: "wav")
    static let aiff = Format(label: "AIFF", ext: "aiff")
    static let flac = Format(label: "FLAC", ext: "flac")
    static let ogg = Format(label: "OGG", ext: "ogg")
    static let opus = Format(label: "Opus", ext: "opus")

    /// All target formats, grouped for Settings.
    static var groups: [(title: String, formats: [Format])] {
        [
            (L.groupImages, [.png, .jpg, .heic, .tiff, .webp, .gif, .bmp, .avif]),
            (L.groupDocuments, [.pdf, .docx, .odt, .rtf, .html, .txt, .md, .epub]),
            (L.groupSheets, [.xlsx, .ods, .csv, .pptx]),
            (L.groupVideo, [.mp4, .mov, .mkv, .webm]),
            (L.groupAudio, [.mp3, .m4a, .wav, .aiff, .flac, .ogg, .opus]),
        ]
    }
}

protocol Converter: Sendable {
    /// Formats a file of this type can be converted to.
    func targets(for type: UTType) -> [Format]
    func convert(_ input: URL, to format: Format, output: URL) async throws
    /// Whether several files may be converted at the same time (cheap, in-process work).
    var concurrent: Bool { get }
}

extension Converter {
    var concurrent: Bool { false }
}

struct ConversionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Runs `body`; if it fails or is cancelled, removes the half-written `output` before rethrowing.
/// Only for outputs at fresh paths (from `outputURL` or `uniqueDestination`), never existing files.
@discardableResult
func removingOutputOnFailure<T>(_ output: URL, _ body: () async throws -> T) async rethrows -> T {
    do {
        return try await body()
    } catch {
        try? FileManager.default.removeItem(at: output)
        throw error
    }
}

extension UTType {
    /// Whether the type conforms to one of the given identifiers.
    func conforms(toAnyOf identifiers: [String]) -> Bool {
        identifiers.contains { id in UTType(id).map { conforms(to: $0) } ?? false }
    }
}

final class ConversionService: Sendable {
    let converters: [Converter]

    init(converters: [Converter]) {
        self.converters = converters
    }

    /// Formats possible for all files, excluding their current format.
    func targets(for urls: [URL]) -> [Format] {
        targets(forTypes: Self.types(of: urls))
    }

    /// Formats possible for files of all the given types, excluding their current format.
    /// When converters overlap, the one listed first wins.
    func targets(forTypes types: [UTType]) -> [Format] {
        let perFile = types.map { type -> [Format] in
            var seen = Set<Format>()
            return converters
                .flatMap { $0.targets(for: type) }
                .filter { $0.type != type && seen.insert($0).inserted }
        }
        guard let first = perFile.first else { return [] }
        return first.filter { format in perFile.allSatisfy { $0.contains(format) } }
    }

    /// Typical input types, used to find out which target formats can be produced at all.
    private static let probeTypes: [UTType] = [
        .png, .pdf, .rtf, .mpeg4Movie, .mp3, .wav,
        UTType("org.openxmlformats.wordprocessingml.document"), UTType("org.openxmlformats.spreadsheetml.sheet"),
        UTType("org.openxmlformats.presentationml.presentation"), UTType("net.daringfireball.markdown"),
        UTType(filenameExtension: "md"),
    ].compactMap { $0 }

    /// All formats the available converters can produce on this Mac.
    var producibleFormats: Set<Format> {
        Set(Self.probeTypes.flatMap { type in converters.flatMap { $0.targets(for: type) } })
    }

    /// The converter that handles this file for the format; the one listed first wins.
    func converter(for url: URL, to format: Format) -> Converter? {
        guard let type = Self.type(of: url) else { return nil }
        return converters.first { $0.targets(for: type).contains(format) }
    }

    /// Whether all files are handled by converters that may run concurrently.
    func isConcurrent(_ urls: [URL], to format: Format) -> Bool {
        urls.allSatisfy { converter(for: $0, to: format)?.concurrent ?? false }
    }

    /// How many files a concurrent converter processes at the same time.
    static let maxConcurrentFiles = 4

    /// Converts each file and puts the result next to it.
    /// Files of concurrent converters are processed up to `maxConcurrentFiles` at a time, others one after another.
    /// With `replaceOriginals`, originals of successfully converted files go to the Trash,
    /// never deleted for good, and on failure the original always stays.
    /// On failure or cancellation, half-written output files are removed.
    /// Returns the successfully converted input files (in input order) and the errors.
    func convert(_ urls: [URL], to format: Format, replaceOriginals: Bool = false,
                 trash: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
    ) async -> (succeeded: [URL], errors: [Error]) {
        let limit = isConcurrent(urls, to: format) ? Self.maxConcurrentFiles : 1
        var results = [Error?](repeating: nil, count: urls.count)
        await withTaskGroup(of: (Int, Error?).self) { group in
            var next = 0
            func addNext() {
                let index = next, url = urls[index]
                next += 1
                group.addTask { (index, await self.convertOne(url, to: format)) }
            }
            while next < min(limit, urls.count) { addNext() }
            for await (index, error) in group {
                results[index] = error
                if next < urls.count { addNext() }
            }
        }
        // Trash in input order, only after the conversions, so the trash callback never runs concurrently.
        var succeeded: [URL] = [], errors: [Error] = []
        for (url, error) in zip(urls, results) {
            if let error {
                errors.append(error)
                continue
            }
            succeeded.append(url)
            if replaceOriginals {
                do { try trash(url) } catch { errors.append(error) }
            }
        }
        return (succeeded, errors)
    }

    /// Converts one file; returns the error instead of throwing it.
    private func convertOne(_ url: URL, to format: Format) async -> Error? {
        do {
            try Task.checkCancellation()
            guard let converter = converter(for: url, to: format)
            else { throw ConversionError(message: L.cannotConvert(url.lastPathComponent, format.label)) }
            let output = Self.reserveOutputURL(for: url, ext: format.ext)
            defer { Self.releaseOutputURL(output) }
            try await removingOutputOnFailure(output) {
                try await converter.convert(url, to: format, output: output)
            }
            return nil
        } catch {
            return error
        }
    }

    /// Output paths handed out but possibly not written yet, so concurrent conversions
    /// (e.g. "photo.png" and "photo.tiff" both to JPG) never pick the same file.
    private static let reservedOutputs = OSAllocatedUnfairLock(initialState: Set<URL>())

    static func reserveOutputURL(for input: URL, ext: String, suffix: String = "") -> URL {
        reservedOutputs.withLock { reserved in
            let url = outputURL(for: input, ext: ext, suffix: suffix, taken: reserved)
            reserved.insert(url)
            return url
        }
    }

    static func releaseOutputURL(_ url: URL) {
        _ = reservedOutputs.withLock { $0.remove(url) }
    }

    static func type(of url: URL) -> UTType? {
        (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
    }

    /// The types of all files in order, or none at all if one of them is unknown.
    static func types(of urls: [URL]) -> [UTType] {
        let types = urls.compactMap(type(of:))
        return types.count == urls.count ? types : []
    }

    /// Types for the given identifiers (UTIs), or none at all if one of them is unknown.
    static func types(identifiers: [String]) -> [UTType] {
        let types = identifiers.compactMap { UTType($0) }
        return types.count == identifiers.count ? types : []
    }

    /// "photo.png" → "photo.jpg", on collision "photo 2.jpg", "photo 3.jpg" …
    /// `taken` lists paths that count as existing.
    static func outputURL(for input: URL, ext: String, suffix: String = "", taken: Set<URL> = []) -> URL {
        let folder = input.deletingLastPathComponent()
        let base = input.deletingPathExtension().lastPathComponent + suffix
        var candidate = folder.appendingPathComponent(base).appendingPathExtension(ext)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) || taken.contains(candidate) {
            candidate = folder.appendingPathComponent("\(base) \(n)").appendingPathExtension(ext)
            n += 1
        }
        return candidate
    }
}
