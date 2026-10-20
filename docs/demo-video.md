# Demo-Video: Plan und Storyboard

Ein kurzes Motion-Graphics-Video für die README und die GitHub-Startseite. Es zeigt einen Beispielordner und führt die stärksten Funktionen vor, mit sichtbarem Mauszeiger und eingeblendeter Taste.

## Eckdaten

| | |
|---|---|
| Länge | ca. 50 Sekunden |
| Format | 1920 × 1080, 60 fps, MP4 (H.264); dazu ein GIF mit 960 px Breite und 15 fps für die README |
| Ton | keiner (GitHub spielt Videos stumm ab), optional eine eigene Fassung mit leiser Musik für Social Media |
| Sprache | Bildtexte kurz und deutsch – *oder* englisch, falls das Repo international auftreten soll (offen) |
| Stil | dunkler, grünlicher Hintergrund wie in den README-Bildern, Limettengrün als einzige Akzentfarbe, ruhige Bewegungen mit weichem Ein- und Ausschwingen |

## Gestaltung

- **Farben:** Hintergrund `#161A14 → #2A3326`, Limette `#A8D63A`, Hervorhebung `#C9EB6A`, Ersetzen-Rot `#FF2D3A`, Text weiß.
- **Schrift:** SF Pro (systemnah). Für einen Export auf anderen Rechnern alternativ Inter.
- **Finder-Fenster:** vereinfachter Nachbau im Dunkelmodus, Listenansicht mit Symbol, Name und Größe. Kein echter Screenshot, damit alles gestochen scharf und gleichbleibend ist.
- **Mauszeiger:** macOS-Pfeil. Bewegt sich auf weichen Bögen, nicht schnurgerade. Die gezogene Datei hängt mit leichter Verzögerung am Zeiger und ist halb transparent wie beim echten Drag.
- **Tasten-Anzeige:** eine Taste unten in der Mitte, wie in den README-Bildern. Im Ruhezustand grau, beim Tippen kurz gedrückt (Skalierung 0,94) und limettengrün mit Beschriftung `⇧ Shift`, `⌘ Cmd` oder `⌃ Ctrl`.
- **Rad:** dieselbe Geometrie und dieselben Farben wie in der App. Es öffnet sich vom Zeiger aus, die Felder erscheinen nacheinander (je 25 ms versetzt) mit leichtem Nachschwingen. Beim Ablegen fällt es zusammen.
- **Neue Datei:** gleitet in die Finder-Liste und leuchtet kurz limettengrün auf.
- **Bildtexte:** oben links, zwei Zeilen. Fett die Funktion, darunter ein kurzer Satz. Ein- und Ausblenden über 300 ms.

## Beispielordner „Projekt“

| Datei | Wofür im Video |
|---|---|
| `Urlaub.heic` | Konvertieren nach JPG, danach Metadaten entfernen |
| `Bericht.docx` | geteiltes Rad: als PDF, Original ersetzen |
| `Rechnung März.pdf`, `Rechnung April.pdf` | Werkzeug: zusammenfügen |
| `Bildschirmaufnahme.mov` | Aktion: Float |
| `Logo.png`, `Interview.wav` | Füllmaterial, damit der Ordner echt wirkt |

## Storyboard

| Zeit | Szene | Was passiert | Bildtext |
|---|---|---|---|
| 0–4 s | **Intro** | Die acht Limettensegmente fliegen von außen zusammen, ein Segment springt heraus wie im Icon. Darunter erscheint „Droplime“. | *Ziehen. Tippen. Ablegen.* |
| 4–7 s | **Ordner** | Das Finder-Fenster „Projekt“ blendet ein, der Mauszeiger fährt herein. | – |
| 7–15 s | **Konvertieren** | Der Zeiger greift `Urlaub.heic` und zieht. Die Taste zeigt **⇧ Shift**, das Rad öffnet sich mit JPG, PNG, TIFF, GIF, PDF … Der Zeiger fährt auf **JPG**, das Feld leuchtet, die Datei wird abgelegt. `Urlaub.jpg` gleitet in die Liste. | **Konvertieren** · Nur Formate, die passen. |
| 15–24 s | **Behalten oder ersetzen** | `Bericht.docx` ziehen, **⇧ Shift**, das geteilte Rad öffnet sich. Der Zeiger bleibt kurz auf dem inneren **PDF** (Bildtext 1), fährt dann nach außen auf den roten Ring (Bildtext 2) und legt ab. `Bericht.docx` fliegt in ein Papierkorb-Symbol in der Ecke, `Bericht.pdf` erscheint. | 1: **Innen** · neue Datei dazu · 2: **Außen** · Original in den Papierkorb |
| 24–32 s | **Zusammenfügen** | Beide Rechnungen werden markiert (Cmd-Klick sichtbar) und gezogen, ein Zähler „2“ hängt am Zeiger. **⌘ Cmd**, das Werkzeug-Rad zeigt *Zusammenfügen* und *ZIP*. Ablegen auf *Zusammenfügen*, `Zusammengefügt.pdf` erscheint, kurz fächern sich die Seiten 1–2 auf. | **Werkzeuge** · Zwei PDFs → eins. |
| 32–38 s | **Metadaten weg** | `Urlaub.jpg` ziehen, **⌘ Cmd**, *Ohne Metadaten*. Ein kleines Info-Kärtchen zeigt „📍 Zürich · iPhone 16“, das durchgestrichen wird und verblasst. | **Ohne Metadaten** · Standort raus, Bild bleibt. |
| 38–44 s | **Float** | `Bildschirmaufnahme.mov` ziehen, **⌃ Ctrl**, das Aktionen-Rad öffnet sich, Ablegen auf **Float**. Ein kleines Vorschaufenster schwebt nach oben rechts. Der Zeiger zieht es kurz an, die Datei löst sich heraus: wieder griffbereit. | **Float** · Dateien parken und später weiterziehen. |
| 44–50 s | **Outro** | Der Ordner blendet aus, das Icon kommt zurück, darunter drei kurze Zeilen. | **Droplime** · Kostenlos & Open Source · Alles lokal, keine Uploads · github.com/domi-bg/droplime |

Bewusst **nicht** im Video: alle weiteren Formate, Kopieren, Verschieben, Pfad, Terminal, AirDrop, ZIP und Einstellungen. Das alles steht in der README.

## Umsetzung

Drei Wege sind möglich:

1. **Programmatisch animiert mit [Remotion](https://www.remotion.dev)** *(Empfehlung)*: Das Video wird als React-Code beschrieben und als MP4 gerendert. Vorteile: jede Bewegung exakt steuerbar, gestochen scharf, das Video liegt als Code im Repo (z. B. `docs/video/`) und lässt sich nach App-Änderungen neu rendern. Rad und Icon werden als SVG mit derselben Geometrie wie in der App nachgebaut. Voraussetzung: Node.js.
2. **Mit der echten App gerendert:** Ein Swift-Skript zeichnet jedes Einzelbild mit dem echten Rad-Code (wie `scripts/make-screenshots.swift`), FFmpeg setzt die Bilder zum Video zusammen. Vorteil: Das Rad ist garantiert identisch mit der App. Nachteil: Die Animation (Bewegungskurven, Texte, Übergänge) muss von Hand programmiert werden.
3. **Echte Bildschirmaufnahme:** mit einem Tool wie Screen Studio oder CleanShot und einer Tasten-Einblendung (z. B. KeyCastr). Wirkt authentisch, sieht aber weniger nach Motion Graphics aus und muss bei jeder Änderung neu aufgenommen werden.

**Vorgehen mit Remotion:**

1. Projekt in `docs/video/` anlegen, Farben und Rad-Geometrie aus der App übernehmen.
2. Bausteine bauen: Finder-Fenster, Mauszeiger mit Bewegungspfaden, Tasten-Anzeige, Rad (normal und geteilt), Bildtext, Float-Fenster.
3. Szenen nach dem Storyboard zusammensetzen und Zeiten feinjustieren.
4. Rendern: `demo.mp4` (1080p) und `demo.gif` (960 px). Ein Standbild aus Szene 3 dient als Vorschaubild.
5. In der README einbinden. Das MP4 lädt man am besten über den GitHub-Editor hoch (eine Datei in die README-Bearbeitung ziehen erzeugt einen `user-attachments`-Link, den GitHub als Video abspielt). Das GIF bleibt als Fallback im Repo.

## Offene Fragen

- Bildtexte auf Deutsch oder Englisch?
- Soll es eine Fassung mit Musik geben, z. B. für Social Media?
- Remotion (Empfehlung) oder lieber die echte App als Grundlage?
