# Demo video: plan and storyboard

A short motion-graphics video for the README and the GitHub page. It shows a sample folder and walks through the most interesting features, with a visible cursor and an on-screen keycap for the key being tapped.

## Key facts

| | |
|---|---|
| Length | about 50 seconds |
| Format | 1920 × 1080, 60 fps, MP4 (H.264); plus a 960 px wide GIF at 15 fps for the README |
| Sound | a silent version (GitHub plays videos muted) and a version with original music and subtle UI sounds |
| Language | English |
| Style | dark, greenish background like the README images, lime as the only accent color, calm motion with soft easing |

## Design

- **Colors:** background `#161A14 → #2A3326`, lime `#B0DB45` for the selected segment, amber `#FABD45` for the *Replace* ring, white text.
- **Font:** SF Pro (close to the system UI); Inter as a fallback for rendering on other machines.
- **Finder window:** a simplified dark-mode replica in list view with icon, name and size. No real screenshot, so everything stays crisp and consistent.
- **Cursor:** the macOS arrow, moving on soft curves rather than straight lines. The dragged file trails the cursor slightly and is semi-transparent, like a real drag.
- **Keycap:** bottom center, as in the README images. Grey at rest; when tapped it presses down (scale 0.94) and turns lime with `⇧ Shift`, `⌘ Cmd` or `⌃ Ctrl`.
- **Wheel:** same look as the app: rounded segments with even 6 px gaps, soft shadows, the selected segment pops out by 8 px like in the app icon. In the split wheel the inner ring says *Keep*, the outer amber ring shows a swap icon and *Replace*. After a small nudge of the file it opens right over the list at the file, segments appear one after another (25 ms apart) with a slight overshoot, and it collapses on drop.
- **New file:** slides into the Finder list and briefly glows lime.
- **Captions:** top left, two lines. The feature in bold, a short sentence below. Fade in and out over 300 ms.

## Sample folder “Project”

| File | Used for |
|---|---|
| `Vacation.heic` | convert to JPG, later strip metadata |
| `Report.docx` | split wheel: to PDF, replacing the original |
| `Invoice March.pdf`, `Invoice April.pdf` | tool: merge |
| `Screen Recording.mov` | action: Float |
| `Logo.png`, `Interview.wav` | filler so the folder looks real |

## Storyboard

| Time | Scene | What happens | Caption |
|---|---|---|---|
| 0–4 s | **Intro** | The eight lime segments fly together, one pops out like in the icon. “Droplime” appears below. | *Drag. Tap. Drop.* |
| 4–7 s | **Folder** | The Finder window “Project” fades in and fills the frame, the cursor moves in. | – |
| 7–15 s | **Convert** | The cursor grabs `Vacation.heic` and nudges it a few pixels. The keycap shows **⇧ Shift**, the wheel opens right over the list at the file with JPG, PNG, TIFF, GIF, PDF … The cursor moves onto **JPG**, the segment lights up, the file is dropped. `Vacation.jpg` slides into the list. | **Convert** · Only formats that fit. |
| 15–24 s | **Keep or replace** | Nudge `Report.docx`, **⇧ Shift**, the split wheel opens over the list. The cursor rests on the inner **PDF** (caption 1), then moves out onto the amber *Replace* ring (caption 2) and drops. `Report.docx` flies into a trash icon in the corner, `Report.pdf` appears. | 1: **Inside** · keep the original · 2: **Outside** · original to Trash |
| 24–32 s | **Merge** | Both invoices get selected (Cmd-click visible) and nudged, a “2” badge on the cursor. **⌘ Cmd**, the wheel opens at the files and shows *Merge* and *ZIP*. Drop on *Merge*, `Merged.pdf` appears, pages 1–2 briefly fan out. | **Tools** · Two PDFs → one. |
| 32–38 s | **Strip metadata** | Nudge `Vacation.jpg`, **⌘ Cmd**, *Strip Metadata*. A small info card “📍 Zurich · iPhone 16” gets crossed out and fades. | **Strip Metadata** · Location gone, photo stays. |
| 38–44 s | **Float** | Nudge `Screen Recording.mov`, **⌃ Ctrl**, the actions wheel opens at the file, drop on **Float**. A small preview window floats to the top right. The cursor tugs at it and the file comes out again: ready when you need it. | **Float** · Park files, drag them on later. |
| 44–50 s | **Outro** | The folder fades out, the icon returns, three short lines below. | **Droplime** · Free & open source · Everything stays on your Mac · github.com/domi-bg/droplime |

Deliberately **not** in the video: the remaining formats, Copy, Move, Path, Terminal, AirDrop, ZIP and Settings. The README covers all of that.

## Production

Built with [Remotion](https://www.remotion.dev): the video is described as React code and rendered to MP4. Every movement is precisely controllable, the output is crisp, and the video lives as code in the repo (`docs/video/`), so it can be re-rendered after app changes. Wheel and icon are rebuilt as SVG using the same geometry as the app.

The music is an original track generated for this video (no third-party music), so it can ship in an open-source repo.

Outputs:

- `docs/video/out/droplime-demo.mp4` with music and `droplime-demo-silent.mp4` (not committed, too large)
- `docs/images/demo.gif` for the README
- a poster frame from the Convert scene

To embed the MP4 on GitHub, drag it into the README editor on github.com. That creates a `user-attachments` link that GitHub plays as a video. The GIF stays in the repo as a fallback.
