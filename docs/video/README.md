# Demo video

The Droplime demo video, built with [Remotion](https://www.remotion.dev) (React → MP4). The storyboard is in [../demo-video.md](../demo-video.md); every moment of the video lives in [src/timeline.ts](src/timeline.ts), and the wheel uses the same geometry and colors as `Sources/Droplime/WheelPanel.swift`.

Needs Node.js 18+, Python 3 with numpy (for the music) and FFmpeg (for the GIF).

```bash
cd docs/video
npm install
npm run music     # synthesizes public/music.wav and public/sfx/*.wav
npx remotion studio
```

The studio shows two compositions: `Demo` (with music and UI sounds) and `DemoSilent`.

## Render

```bash
npm run render    # out/droplime-demo.mp4 (music) and out/droplime-demo-silent.mp4
npm run poster    # out/poster.png (copy to ../images/demo-poster.png)
npm run gif       # ../images/demo.gif, 960 px, 15 fps, from the silent render
```

`out/` is not committed. To show the MP4 on GitHub, drag it into the README editor on github.com; GitHub uploads it and inserts a `user-attachments` link that plays inline.

For a quick look at single frames: `node scripts/stills.mjs 10.5 20.8` writes `out/stills/<seconds>s.png`.

## Music

`scripts/make-music.py` generates the soundtrack and the UI sounds (key tick, click, drop pop, chime) from scratch with numpy: a calm loop in D major at 100 BPM with soft pads, a plucked arpeggio, bass and light percussion, 50 seconds with fade-in and fade-out. No samples or third-party recordings are used, so the audio is covered by the repository's MIT license.

To use a different track instead, put it at `public/music.wav` (or change the file name in `src/Demo.tsx`) and note its source and license here. Royalty-free sources include the [YouTube Audio Library](https://studio.youtube.com/channel/UC/music) and [Pixabay Music](https://pixabay.com/music/).
