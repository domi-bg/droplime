<p align="center">
  <img src="docs/images/icon.png" width="160" alt="Droplime-Icon">
</p>

<h1 align="center">Droplime</h1>

<p align="center">
  <b>Ziehen. Tippen. Ablegen.</b><br>
  Dateien konvertieren, bearbeiten und verschicken – direkt beim Ziehen, ohne ein Fenster zu öffnen.
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-1d1f1b?logo=apple">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.10-a8d63a?logo=swift&logoColor=white">
  <img alt="Lizenz: MIT" src="https://img.shields.io/badge/Lizenz-MIT-a8d63a">
  <img alt="Offline" src="https://img.shields.io/badge/100%25-offline-1d1f1b">
</p>

---

Droplime lebt unauffällig in der Menüleiste. Während du eine Datei ziehst – aus dem Finder, vom Schreibtisch, aus fast jeder App – tippst du kurz eine Taste, und am Mauszeiger öffnet sich ein Rad mit genau den Möglichkeiten, die zu dieser Datei passen. Lass die Datei auf einem Feld los, und das Ergebnis liegt direkt neben dem Original.

| Taste beim Ziehen | Rad | Wofür |
|---|---|---|
| <kbd>⇧ Shift</kbd> | **Konvertieren** | in ein anderes Format umwandeln |
| <kbd>⌘ Cmd</kbd> | **Werkzeuge** | verkleinern, zusammenfügen, Metadaten entfernen, packen … |
| <kbd>⌃ Ctrl</kbd> | **Aktionen** | AirDrop, kopieren, verschieben, Pfad, Terminal, Float |

Eine andere Taste wechselt das Rad. Loslassen in der Mitte oder außerhalb bricht ab – die Datei landet dann ganz normal dort, wo du sie hingezogen hast.

## Inhalt

- [Konvertieren](#konvertieren)
- [Original behalten oder ersetzen](#original-behalten-oder-ersetzen)
- [Werkzeuge](#werkzeuge)
- [Aktionen](#aktionen)
- [Einstellungen](#einstellungen)
- [Datenschutz](#datenschutz)
- [Installation](#installation)
- [Entwicklung](#entwicklung)
- [Grenzen und Pläne](#grenzen-und-pläne)

## Konvertieren

<img src="docs/images/wheel-convert.png" width="340" align="right" alt="Konvertieren-Rad mit einer PNG-Datei">

Das Rad zeigt nur Formate, in die sich die gezogene Datei **wirklich** umwandeln lässt – das aktuelle Format fehlt, und bei mehreren Dateien bleiben nur Formate übrig, die für alle passen.

Grundausstattung, ganz ohne Zusatzsoftware:

- **Bilder** – PNG, JPG, HEIC, TIFF, GIF, BMP, SVG und RAW lesen → PNG, JPG, HEIC, TIFF, GIF, BMP, **PDF**
- **PDF** → PNG oder JPG (eine Datei pro Seite), **TXT** (Text herausziehen)
- **Textdokumente** – DOCX, DOC, ODT, RTF, HTML, TXT → DOCX, ODT, RTF, HTML, TXT, **PDF**
- **Video** – MP4, MOV, M4V → MP4, MOV, **M4A** (nur den Ton)
- **Audio** – MP3, M4A, WAV, AIFF, FLAC, CAF → M4A, WAV, AIFF

<br clear="right">

Mit optionalen Zusatzwerkzeugen wird das Rad größer – Droplime findet sie automatisch und bietet nur an, was mit der installierten Version tatsächlich funktioniert:

| Werkzeug | Installation | Zusätzlich |
|---|---|---|
| [FFmpeg](https://ffmpeg.org) | `brew install ffmpeg` | MKV, WebM, animiertes GIF aus Video, MP3, FLAC, Opus, OGG – und Videos in Formaten, die macOS selbst nicht liest |
| [LibreOffice](https://www.libreoffice.org) | `brew install --cask libreoffice` | originalgetreues DOCX → PDF, Tabellen (XLSX, ODS, CSV), Präsentationen (PPTX → PDF) |
| [Pandoc](https://pandoc.org) | `brew install pandoc` | Markdown ↔ DOCX, HTML, ODT, EPUB |

Gibt es den Dateinamen schon, entsteht `Name 2.jpg` – Droplime überschreibt nie etwas.

## Original behalten oder ersetzen

<img src="docs/images/wheel-split.png" width="340" align="right" alt="Geteiltes Rad: innen behalten, außen ersetzen">

In den Einstellungen legst du fest, was mit dem Original passiert:

- **Original behalten** *(Standard)* – die neue Datei kommt dazu.
- **Original ersetzen** – das Original wandert in den Papierkorb.
- **Im Rad wählen** – jedes Feld ist zweigeteilt: **innen** behalten, **außen** (rot, mit Papierkorb) ersetzen. Du entscheidest bei jedem Ablegen neu.

Sicherheitsnetz: Ersetzte Originale landen **immer im Papierkorb** und werden nie endgültig gelöscht. Schlägt eine Konvertierung fehl, bleibt das Original unangetastet – bei mehreren Dateien gilt das für jede einzeln.

<br clear="right">

## Werkzeuge

<img src="docs/images/wheel-tools.png" width="340" align="right" alt="Werkzeuge-Rad mit zwei PDFs">

Auch das Werkzeug-Rad passt sich an: Zwei PDFs bieten *Zusammenfügen*, ein Foto bietet *Verkleinern* und *Ohne Metadaten*. Werkzeuge erzeugen immer eine **neue** Datei und lassen das Original in Ruhe.

| Dateien | Werkzeug | Ergebnis |
|---|---|---|
| Bilder | **Verkleinern** | halbe Kantenlänge, `Foto (klein).jpg` |
| | **Drehen** | 90° im Uhrzeigersinn |
| | **Ohne Metadaten** | entfernt Standort (GPS), Kameradaten und XMP – verlustfrei, die Ausrichtung bleibt |
| PDF | **Teilen** | eine PDF pro Seite |
| | **Komprimieren** | Bilder im PDF verkleinert |
| | **Drehen** | alle Seiten um 90° |
| mehrere PDFs und Bilder | **Zusammenfügen** | ein PDF in der Reihenfolge der Auswahl |
| Video | **Komprimieren** | HEVC, höchstens 1080p – meist ein Bruchteil der Größe |
| | **Ohne Ton** | Tonspur entfernt, Bild bleibt unverändert |
| Audio | **Komprimieren** | AAC mit 96 kbit/s |
| alles, auch Ordner | **ZIP** | wie „Komprimieren“ im Finder, bei mehreren Objekten `Archiv.zip` |
| ZIP | **Entpacken** | in einen Ordner daneben |

<br clear="right">

## Aktionen

<img src="docs/images/wheel-actions.png" width="340" align="right" alt="Aktionen-Rad">

Aktionen funktionieren mit allem – Dateien, Ordnern, gemischten Auswahlen:

- **AirDrop** – öffnet direkt die AirDrop-Auswahl.
- **Kopieren / Verschieben** – fragt nach dem Zielordner (und merkt sich den letzten). Gleichnamige Dateien werden nie überschrieben.
- **Pfad** – kopiert den vollständigen Pfad in die Zwischenablage, bei mehreren Dateien einen pro Zeile.
- **Terminal** – öffnet den Ordner der Datei im Terminal.
- **Float** – parkt die Datei als kleines, immer sichtbares Vorschaufenster am Bildschirmrand. Von dort lässt sie sich jederzeit wieder herausziehen – in eine Mail, in einen Upload, oder mit <kbd>⇧</kbd> zurück ins Droplime-Rad.

<br clear="right">

## Einstellungen

<img src="docs/images/settings.png" width="380" align="right" alt="Einstellungsfenster">

Über das Limetten-Symbol in der Menüleiste → **Einstellungen …** (<kbd>⌘ ,</kbd>):

- **Nach dem Konvertieren** – behalten, ersetzen oder im Rad wählen (siehe oben).
- **Formate im Rad** – Häkchen weg bei Formaten, die du nie brauchst; sie tauchen dann nie mehr im Rad auf. Die kluge Vorauswahl bleibt: Es erscheinen nur Formate, die zur Datei passen *und* angehakt sind.
- **Zusatzwerkzeuge** – zeigt, ob FFmpeg, LibreOffice und Pandoc gefunden wurden, und wie man sie installiert. Ausgegraute Formate verraten per Tooltip, welches Werkzeug sie freischaltet.

<br clear="right">

## Datenschutz

- **Alles passiert lokal.** Droplime hat keinen Netzwerkcode – keine Uploads, keine Konten, keine Telemetrie.
- **Keine Sonderrechte nötig.** Droplime erkennt Ziehen und Tastentipps, ohne Bedienungshilfen- oder Bildschirmaufnahme-Berechtigung.
- **Nichts geht verloren.** Originale werden nur auf Wunsch ersetzt und landen dann im Papierkorb.

## Installation

Voraussetzungen: macOS 14 (Sonoma) oder neuer, Xcode bzw. die Swift-Toolchain.

```bash
git clone https://github.com/domi-bg/droplime.git
cd droplime
./scripts/build-app.sh
open build/Droplime.app
```

`build/Droplime.app` kannst du nach `/Applications` ziehen. Damit Droplime beim Anmelden startet: *Systemeinstellungen → Allgemein → Anmeldeobjekte* → Droplime hinzufügen.

Für mehr Formate optional:

```bash
brew install ffmpeg pandoc
brew install --cask libreoffice
```

Danach Droplime neu starten.

## Entwicklung

```bash
swift run      # direkt starten, Meldungen erscheinen im Terminal
swift test     # Tests: echte Beispieldateien durch jedes Format und jedes Werkzeug
```

| Pfad | Inhalt |
|---|---|
| `Sources/Droplime/DragWatcher.swift` | erkennt systemweit Datei-Drags und Tastentipps |
| `Sources/Droplime/WheelPanel.swift` | das Rad am Mauszeiger, Ablegen, geteilte Felder |
| `Sources/Droplime/Conversion/` | ein `Converter` pro Engine (ImageIO, PDFKit, textutil, AVFoundation, FFmpeg, LibreOffice, Pandoc) |
| `Sources/Droplime/Tools/` | Werkzeuge (`Tool`) für Bilder, PDFs, Medien, Archive |
| `Sources/Droplime/Actions/` | Aktionen und das Float-Fenster |
| `Sources/Droplime/LimeIcon.swift` | App- und Menüleisten-Symbol, als Code gezeichnet |
| `scripts/` | App bauen, Icon und README-Bilder neu erzeugen |

**Neues Format:** `Converter` implementieren (`targets(for:)`, `convert(_:to:output:)`) und in `AppDelegate` eintragen – die Reihenfolge der Liste bestimmt, welcher Konverter bei Überschneidungen gewinnt.
**Neues Werkzeug:** `Tool` implementieren (`applies(to:)`, `run(_:)`) und in `ToolService.standard()` eintragen.

Bilder neu erzeugen: `./scripts/make-icon.sh` (App-Icon) und `./scripts/make-screenshots.sh` (Bilder in dieser README).

## Grenzen und Pläne

- Werkzeuge mit Auswahl – Video **kürzen**, Bild **zuschneiden** – brauchen eine kleine Oberfläche und fehlen noch.
- Die Tasten sind fest (Shift, Cmd, Ctrl) und noch nicht umstellbar.
- Bei langen Konvertierungen gibt es noch keine Fortschrittsanzeige; ein Ton meldet das Ende.
- Das Rad zeigt höchstens 10 Einträge; die Reihenfolge ist noch nicht einstellbar.

Ideen und Pull Requests sind willkommen.

## Danke

Inspiriert von [Tangerine](https://tangerineformac.com) und [Convierto](https://github.com/nuance-dev/convierto). Droplime ist ein unabhängiges Projekt und enthält keinen Code dieser Apps.

## Lizenz

[MIT](LICENSE)
