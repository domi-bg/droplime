import Foundation

/// Sprache der App. `system` folgt der Systemsprache: Deutsch, wenn sie Deutsch ist, sonst Englisch.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, german, english

    var id: String { rawValue }

    /// Die tatsächlich verwendete Sprache.
    var resolved: AppLanguage {
        self == .system ? Self.resolve(preferred: Locale.preferredLanguages) : self
    }

    static func resolve(preferred: [String]) -> AppLanguage {
        preferred.first?.lowercased().hasPrefix("de") == true ? .german : .english
    }

    /// Name der Sprache in der Sprache selbst, wie in macOS üblich.
    var label: String {
        switch self {
        case .system: return L.languageSystem(Self.resolve(preferred: Locale.preferredLanguages).label)
        case .german: return "Deutsch"
        case .english: return "English"
        }
    }
}

/// Alle sichtbaren Texte der App. Eine neue Zeichenkette muss in jeder Sprache ergänzt werden,
/// sonst baut die App nicht – so kann keine Übersetzung vergessen werden.
struct Strings {
    // Rad
    let modeConvert, modeTools, modeActions, nothingPossible: String

    // Menü und Einstellungen
    let menuSettings, menuQuit, settingsWindowTitle: String
    let settingsLanguage: String
    let languageSystem: (String) -> String
    let settingsAfterConversion, afterKeep, afterReplace, afterSplit: String
    let settingsFormats, settingsFormatsFooter: String
    let groupImages, groupDocuments, groupSheets, groupVideo, groupAudio: String
    let settingsTools, toolFound, restartAfterInstall, notAvailableHere: String
    let needsTool: (String) -> String

    // Werkzeuge und Dateinamen
    let toolResize, toolRotate, toolStripMetadata, toolMerge, toolSplit, toolCompress, toolRemoveAudio, toolZip, toolUnzip: String
    let suffixSmall, suffixRotated, suffixNoMetadata, suffixCompressed, suffixNoAudio: String
    let pageSuffix: (Int) -> String
    let mergedFileName, archiveFileName: String

    // Aktionen
    let actionAirDrop, actionCopy, actionMove, actionPath, actionTerminal, actionFloat: String
    let copyTo, moveTo, choose: String
    let floatItems: (Int) -> String
    let floatMore: (Int) -> String
    let floatTooltip: String

    // Fehler
    let conversionFailed, actionFailed: String
    let toolFailed: (String) -> String
    let cannotRead, cannotWrite, cannotOpen, cannotRotate, noText, onlyOnePage: (String) -> String
    let notSupported: (String) -> String
    let cannotConvert: (String, String) -> String
    let exportFailed, pdfFailed, pageFailed, airDropUnavailable, terminalNotFound: String
    let externalToolFailed: (String, String) -> String

    static let german = Strings(
        modeConvert: "Konvertieren", modeTools: "Werkzeuge", modeActions: "Aktionen", nothingPossible: "Nichts möglich",
        menuSettings: "Einstellungen …", menuQuit: "Droplime beenden", settingsWindowTitle: "Droplime Einstellungen",
        settingsLanguage: "Sprache",
        languageSystem: { "Systemsprache (\($0))" },
        settingsAfterConversion: "Nach dem Konvertieren",
        afterKeep: "Original behalten",
        afterReplace: "Original ersetzen (in den Papierkorb)",
        afterSplit: "Im Rad wählen: innen behalten, außen ersetzen",
        settingsFormats: "Formate im Rad",
        settingsFormatsFooter: "Droplime schlägt nur Formate vor, die zu den gezogenen Dateien passen. Hier blendest du Formate aus, die du nie brauchst. Ausgegraute Formate brauchen ein Zusatzwerkzeug (siehe unten); der Tooltip verrät, welches.",
        groupImages: "Bilder", groupDocuments: "Dokumente", groupSheets: "Tabellen & Präsentationen",
        groupVideo: "Video", groupAudio: "Audio",
        settingsTools: "Zusatzwerkzeuge", toolFound: "gefunden",
        restartAfterInstall: "Nach der Installation Droplime neu starten.",
        notAvailableHere: "Auf diesem Mac nicht verfügbar",
        needsTool: { "Braucht \($0)" },
        toolResize: "Verkleinern", toolRotate: "Drehen", toolStripMetadata: "Ohne Metadaten", toolMerge: "Zusammenfügen",
        toolSplit: "Teilen", toolCompress: "Komprimieren", toolRemoveAudio: "Ohne Ton", toolZip: "ZIP", toolUnzip: "Entpacken",
        suffixSmall: " (klein)", suffixRotated: " (gedreht)", suffixNoMetadata: " (ohne Metadaten)",
        suffixCompressed: " (komprimiert)", suffixNoAudio: " (ohne Ton)",
        pageSuffix: { " – Seite \($0)" },
        mergedFileName: "Zusammengefügt", archiveFileName: "Archiv",
        actionAirDrop: "AirDrop", actionCopy: "Kopieren", actionMove: "Verschieben", actionPath: "Pfad",
        actionTerminal: "Terminal", actionFloat: "Float",
        copyTo: "Kopieren nach", moveTo: "Verschieben nach", choose: "Auswählen",
        floatItems: { "\($0) Objekte" },
        floatMore: { "+\($0) weitere" },
        floatTooltip: "Zum Verwenden herausziehen",
        conversionFailed: "Konvertierung fehlgeschlagen", actionFailed: "Aktion fehlgeschlagen",
        toolFailed: { "\($0) fehlgeschlagen" },
        cannotRead: { "\($0) konnte nicht gelesen werden." },
        cannotWrite: { "\($0) konnte nicht geschrieben werden." },
        cannotOpen: { "\($0) konnte nicht geöffnet werden." },
        cannotRotate: { "\($0) konnte nicht gedreht werden." },
        noText: { "\($0) enthält keinen Text (vielleicht ein Scan?)." },
        onlyOnePage: { "\($0) hat nur eine Seite." },
        notSupported: { "\($0) wird nicht unterstützt." },
        cannotConvert: { "\($0) kann nicht in \($1) umgewandelt werden." },
        exportFailed: "Export fehlgeschlagen.", pdfFailed: "PDF konnte nicht erstellt werden.",
        pageFailed: "Seite konnte nicht gespeichert werden.",
        airDropUnavailable: "AirDrop ist auf diesem Mac nicht verfügbar.",
        terminalNotFound: "Terminal wurde nicht gefunden.",
        externalToolFailed: { "\($0) ist fehlgeschlagen:\n\($1)" }
    )

    static let english = Strings(
        modeConvert: "Convert", modeTools: "Tools", modeActions: "Actions", nothingPossible: "Nothing to do",
        menuSettings: "Settings …", menuQuit: "Quit Droplime", settingsWindowTitle: "Droplime Settings",
        settingsLanguage: "Language",
        languageSystem: { "System language (\($0))" },
        settingsAfterConversion: "After converting",
        afterKeep: "Keep original",
        afterReplace: "Replace original (move to Trash)",
        afterSplit: "Choose in the wheel: inside keeps, outside replaces",
        settingsFormats: "Formats in the wheel",
        settingsFormatsFooter: "Droplime only suggests formats that fit the dragged files. Hide formats here that you never need. Greyed-out formats need an extra tool (see below); the tooltip tells you which.",
        groupImages: "Images", groupDocuments: "Documents", groupSheets: "Spreadsheets & presentations",
        groupVideo: "Video", groupAudio: "Audio",
        settingsTools: "Extra tools", toolFound: "found",
        restartAfterInstall: "Restart Droplime after installing.",
        notAvailableHere: "Not available on this Mac",
        needsTool: { "Needs \($0)" },
        toolResize: "Resize", toolRotate: "Rotate", toolStripMetadata: "Strip Metadata", toolMerge: "Merge",
        toolSplit: "Split", toolCompress: "Compress", toolRemoveAudio: "Remove Audio", toolZip: "ZIP", toolUnzip: "Unzip",
        suffixSmall: " (small)", suffixRotated: " (rotated)", suffixNoMetadata: " (no metadata)",
        suffixCompressed: " (compressed)", suffixNoAudio: " (no audio)",
        pageSuffix: { " – Page \($0)" },
        mergedFileName: "Merged", archiveFileName: "Archive",
        actionAirDrop: "AirDrop", actionCopy: "Copy", actionMove: "Move", actionPath: "Path",
        actionTerminal: "Terminal", actionFloat: "Float",
        copyTo: "Copy to", moveTo: "Move to", choose: "Choose",
        floatItems: { "\($0) items" },
        floatMore: { "+\($0) more" },
        floatTooltip: "Drag out to use",
        conversionFailed: "Conversion failed", actionFailed: "Action failed",
        toolFailed: { "\($0) failed" },
        cannotRead: { "Couldn’t read \($0)." },
        cannotWrite: { "Couldn’t write \($0)." },
        cannotOpen: { "Couldn’t open \($0)." },
        cannotRotate: { "Couldn’t rotate \($0)." },
        noText: { "\($0) contains no text (maybe a scan?)." },
        onlyOnePage: { "\($0) has only one page." },
        notSupported: { "\($0) isn’t supported." },
        cannotConvert: { "\($0) can’t be converted to \($1)." },
        exportFailed: "Export failed.", pdfFailed: "Couldn’t create the PDF.",
        pageFailed: "Couldn’t save the page.",
        airDropUnavailable: "AirDrop isn’t available on this Mac.",
        terminalNotFound: "Terminal wasn’t found.",
        externalToolFailed: { "\($0) failed:\n\($1)" }
    )
}

/// Die Texte in der aktuell eingestellten Sprache.
var L: Strings { Settings.shared.language.resolved == .german ? .german : .english }
