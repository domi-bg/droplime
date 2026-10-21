import Foundation
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

protocol Converter {
    /// Formats a file of this type can be converted to.
    func targets(for type: UTType) -> [Format]
    func convert(_ input: URL, to format: Format, output: URL) async throws
}

struct ConversionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

extension UTType {
    /// Whether the type conforms to one of the given identifiers.
    func conforms(toAnyOf identifiers: [String]) -> Bool {
        identifiers.contains { id in UTType(id).map { conforms(to: $0) } ?? false }
    }
}

final class ConversionService {
    let converters: [Converter]

    init(converters: [Converter]) {
        self.converters = converters
    }

    /// Formats possible for all files, excluding their current format.
    /// When converters overlap, the one listed first wins.
    func targets(for urls: [URL]) -> [Format] {
        let perFile = urls.map { url -> [Format] in
            guard let type = Self.type(of: url) else { return [] }
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

    /// Converts each file and puts the result next to it.
    /// With `replaceOriginals`, originals of successfully converted files go to the Trash,
    /// never deleted for good, and on failure the original always stays.
    /// Returns the successfully converted input files and the errors.
    func convert(_ urls: [URL], to format: Format, replaceOriginals: Bool = false,
                 trash: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
    ) async -> (succeeded: [URL], errors: [Error]) {
        var succeeded: [URL] = [], errors: [Error] = []
        for url in urls {
            do {
                guard let type = Self.type(of: url),
                      let converter = converters.first(where: { $0.targets(for: type).contains(format) })
                else { throw ConversionError(message: L.cannotConvert(url.lastPathComponent, format.label)) }
                try await converter.convert(url, to: format, output: Self.outputURL(for: url, ext: format.ext))
                succeeded.append(url)
                if replaceOriginals { try trash(url) }
            } catch {
                errors.append(error)
            }
        }
        return (succeeded, errors)
    }

    static func type(of url: URL) -> UTType? {
        (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
    }

    /// "photo.png" → "photo.jpg", on collision "photo 2.jpg", "photo 3.jpg" …
    static func outputURL(for input: URL, ext: String, suffix: String = "") -> URL {
        let folder = input.deletingLastPathComponent()
        let base = input.deletingPathExtension().lastPathComponent + suffix
        var candidate = folder.appendingPathComponent(base).appendingPathExtension(ext)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) \(n)").appendingPathExtension(ext)
            n += 1
        }
        return candidate
    }
}
