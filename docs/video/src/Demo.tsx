import {AbsoluteFill, Html5Audio, Sequence, staticFile, useCurrentFrame} from 'remotion';
import {Finder} from './components/Finder';
import {LimeMark} from './components/LimeMark';
import {Captions, CmdClick, Cursor, FloatWindow, Ghosts, KeyCap, MetaCard, PageFan, Trash} from './components/Overlays';
import {Wheel} from './components/Wheel';
import {C, DURATION, FONT, FPS, easeIn, easeOut, prog, springy, windowed} from './theme';
import {CLICKS, ROWS, WHEELS, cursorAt} from './timeline';

const Background: React.FC = () => (
  <AbsoluteFill style={{background: `linear-gradient(170deg, ${C.bgTop} 0%, ${C.bgBottom} 75%)`}}>
    <AbsoluteFill style={{background: 'radial-gradient(ellipse at 70% 45%, rgba(168,214,58,0.06), transparent 60%)'}} />
  </AbsoluteFill>
);

const Title: React.FC<{t: number; at: number; top: number; lines: {text: string; size: number; color: string; weight: number}[]}> = ({t, at, top, lines}) => (
  <div style={{position: 'absolute', left: 0, right: 0, top, textAlign: 'center', fontFamily: FONT}}>
    {lines.map((l, i) => {
      const p = prog(t, at + i * 0.35, at + i * 0.35 + 0.6, easeOut);
      return (
        <div key={l.text} style={{fontSize: l.size, fontWeight: l.weight, color: l.color, opacity: p, letterSpacing: l.size > 60 ? -1.5 : 0,
          transform: `translateY(${(1 - p) * 18}px)`, marginTop: i === 0 ? 0 : 14}}>{l.text}</div>
      );
    })}
  </div>
);

const Intro: React.FC<{t: number}> = ({t}) => {
  if (t > 4.1) return null;
  const out = prog(t, 3.5, 4.0, easeIn);
  return (
    <AbsoluteFill style={{opacity: 1 - out, transform: `scale(${1 + 0.04 * out})`}}>
      <div style={{position: 'absolute', left: 960 - 170, top: 250}}>
        <LimeMark size={340} id="intro" assemble={(i) => springy(t - 0.2 - i * 0.07, 0.9)} pop={springy(t - 1.45, 0.5)} />
      </div>
      <Title t={t} at={1.75} top={640} lines={[
        {text: 'Droplime', size: 104, color: '#fff', weight: 800},
        {text: 'Drag. Tap. Drop.', size: 46, color: C.lime, weight: 600},
      ]} />
    </AbsoluteFill>
  );
};

const Outro: React.FC<{t: number}> = ({t}) => {
  const at = 44.5;
  if (t < at) return null;
  const end = prog(t, DURATION - 0.6, DURATION, easeIn);
  return (
    <AbsoluteFill style={{opacity: 1 - end}}>
      <div style={{position: 'absolute', left: 960 - 150, top: 220}}>
        <LimeMark size={300} id="outro" assemble={(i) => springy(t - at - i * 0.05, 0.8)} pop={springy(t - at - 0.75, 0.5)} />
      </div>
      <Title t={t} at={at + 0.9} top={580} lines={[
          {text: 'Droplime', size: 92, color: '#fff', weight: 800},
          {text: 'Free & open source · Everything stays on your Mac', size: 36, color: 'rgba(255,255,255,0.8)', weight: 500},
          {text: 'github.com/domi-bg/droplime', size: 36, color: C.lime, weight: 600},
      ]} />
    </AbsoluteFill>
  );
};

const Sfx: React.FC<{at: number; src: string; volume: number}> = ({at, src, volume}) => (
  <Sequence from={Math.round(at * FPS)} durationInFrames={FPS * 2} layout="none">
    <Html5Audio src={staticFile(src)} volume={volume} />
  </Sequence>
);

const Sound: React.FC = () => (
  <>
    <Html5Audio src={staticFile('music.wav')} volume={0.8} />
    <Sfx at={1.45} src="sfx/chime.wav" volume={0.5} />
    {CLICKS.map((c) => <Sfx key={c} at={c} src="sfx/click.wav" volume={0.35} />)}
    {WHEELS.map((w) => <Sfx key={`tap${w.tap}`} at={w.tap} src="sfx/tick.wav" volume={0.55} />)}
    {WHEELS.map((w) => <Sfx key={`drop${w.drop}`} at={w.drop} src="sfx/pop.wav" volume={0.6} />)}
    {ROWS.filter((r) => r.appearAt !== undefined).map((r) => (
      <Sfx key={r.name} at={r.appearAt! + 0.3} src="sfx/chime.wav" volume={0.22} />
    ))}
    <Sfx at={22.7} src="sfx/pop.wav" volume={0.3} />
    <Sfx at={45.25} src="sfx/chime.wav" volume={0.45} />
  </>
);

export const Demo: React.FC<{sound: boolean}> = ({sound}) => {
  const frame = useCurrentFrame();
  const t = frame / FPS;
  const cursor = cursorAt(t);
  const stage = windowed(t, 4.0, 44.6, 0.5);
  return (
    <AbsoluteFill style={{fontFamily: FONT}}>
      <Background />
      <Intro t={t} />
      <Finder t={t} />
      <Trash t={t} />
      <Captions t={t} />
      <FloatWindow t={t} />
      {WHEELS.map((w) => <Wheel key={w.tap} w={w} t={t} cursor={cursor} />)}
      <PageFan t={t} />
      <MetaCard t={t} />
      <AbsoluteFill style={{opacity: stage}}>
        <Ghosts t={t} />
        <Cursor t={t} />
        <CmdClick t={t} />
      </AbsoluteFill>
      <KeyCap t={t} />
      <Outro t={t} />
      {sound && <Sound />}
    </AbsoluteFill>
  );
};
