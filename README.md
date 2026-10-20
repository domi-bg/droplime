# Droplime

Datei ziehen, Taste tippen, ablegen – fertig konvertiert.

Droplime ist ein Datei-Konverter für macOS, der ohne Fenster auskommt. Während du eine Datei ziehst (z. B. im Finder), tippst du kurz eine Taste, und am Mauszeiger erscheint ein Rad mit passenden Zielformaten. Lässt du die Datei auf einem Format los, liegt die umgewandelte Datei gleich neben dem Original. Alles läuft lokal auf deinem Mac.

| Taste | Rad |
|---|---|
| Shift | Konvertieren |
| Cmd | Werkzeuge *(in Arbeit)* |
| Ctrl | Aktionen *(in Arbeit)* |

Ablegen in der Mitte des Rads oder daneben bricht ab.

## Einstellungen

Über das Limetten-Symbol in der Menüleiste → **Einstellungen …** (Cmd+,):

- **Nach dem Konvertieren:** Original behalten (Standard), Original ersetzen, oder im Rad wählen. Beim geteilten Rad bedeutet der innere Ring „zusätzlich“ und der äußere, rote Ring „ersetzen“. Ersetzte Originale wandern in den Papierkorb und werden nie endgültig gelöscht. Schlägt eine Konvertierung fehl, bleibt das Original immer liegen.
- **Formate im Rad:** Formate abwählen, die du nie brauchst. Ausgegraute Formate brauchen ein Zusatzwerkzeug.

## Formate

Ohne zusätzliche Software, nur mit Bordmitteln von macOS:

- **Bilder** (PNG, JPG, HEIC, TIFF, GIF, BMP, SVG als Eingabe …) → PNG, JPG, HEIC, TIFF, GIF, BMP, PDF
- **PDF** → PNG, JPG (eine Datei pro Seite), TXT
- **Textdokumente** (DOCX, DOC, ODT, RTF, HTML, TXT) → DOCX, ODT, RTF, HTML, TXT, PDF
- **Video** (MP4, MOV, M4V …) → MP4, MOV, M4A
- **Audio** (MP3, M4A, WAV, AIFF, FLAC …) → M4A, WAV, AIFF

Mehr Formate, wenn diese Werkzeuge installiert sind (Droplime findet sie automatisch):

| Werkzeug | Installation | Zusätzlich |
|---|---|---|
| [FFmpeg](https://ffmpeg.org) | `brew install ffmpeg` | MKV, WebM, GIF aus Video, MP3, FLAC, Opus, OGG |
| [LibreOffice](https://www.libreoffice.org) | `brew install --cask libreoffice` | bessere DOCX→PDF-Ergebnisse, XLSX/ODS/CSV, PPTX → PDF |
| [Pandoc](https://pandoc.org) | `brew install pandoc` | Markdown ↔ DOCX/HTML/ODT/EPUB |

Welche Werkzeuge gefunden wurden, steht im Menü des Droplime-Symbols in der Menüleiste. Es werden nur Formate angeboten, die mit der installierten Version wirklich funktionieren.

## Starten

Voraussetzung: macOS 14 oder neuer und Xcode (bzw. die Swift-Toolchain).

Zum Entwickeln direkt starten:

```bash
swift run
```

Als richtige App mit Icon bauen (landet in `build/Droplime.app`, kann nach `/Applications` gezogen werden):

```bash
./scripts/build-app.sh
```

Das App-Icon wird aus `Sources/Droplime/LimeIcon.swift` gezeichnet; nach Änderungen dort `./scripts/make-icon.sh` ausführen.

Tests:

```bash
swift test
```

## Aufbau

- `Sources/Droplime/DragWatcher.swift` – erkennt systemweit Datei-Drags und Tastentipps (ohne Bedienungshilfen-Berechtigung)
- `Sources/Droplime/WheelPanel.swift` – das Rad am Mauszeiger und das Ablegen
- `Sources/Droplime/Conversion/` – ein `Converter` pro Engine; `ConversionService` wählt pro Format den ersten passenden

Einen neuen Konverter hinzufügen: das Protokoll `Converter` implementieren (`targets(for:)` und `convert(_:to:output:)`) und ihn in `AppDelegate` in die Liste eintragen.

## Danke

Inspiriert von [Tangerine](https://tangerineformac.com) und [Convierto](https://github.com/nuance-dev/convierto). Droplime ist ein unabhängiges Projekt und enthält keinen Code dieser Apps.

## Lizenz

[MIT](LICENSE)
