import {C, FONT, UI, clamp01, easeIn, easeInOut, easeOut, lerp, prog, springy, windowed} from '../theme';
import {CAPTIONS, CLICKS, DRAGS, FAN, FLOAT, META, TRASH, WHEELS, cursorAt, keyCapActive} from '../timeline';
import {FileIcon} from './FileIcon';
import {rowIconCenter} from './Finder';

const abs = (x: number, y: number): React.CSSProperties => ({position: 'absolute', left: x, top: y});

// ---- Cursor & dragged files ------------------------------------------------------------------

export const Cursor: React.FC<{t: number}> = ({t}) => {
  const {x, y} = cursorAt(t);
  const press = Math.max(0, ...CLICKS.map((c) => (t >= c - 0.06 && t < c + 0.16 ? Math.sin(((t - c + 0.06) / 0.22) * Math.PI) : 0)));
  const s = UI * 1.15 * (1 - 0.12 * press);
  return (
    <svg width={24 * s} height={30 * s} viewBox="0 0 24 30"
      style={{...abs(x - 1.5 * s, y - 1.5 * s), overflow: 'visible', filter: 'drop-shadow(0 3px 4px rgba(0,0,0,0.45))'}}>
      <path d="M1.5 1.5 L1.5 21 L6 16.7 L9.1 23.9 L12.2 22.6 L9.2 15.6 L15.4 15.6 Z" fill="#000" stroke="#fff"
        strokeWidth="1.5" strokeLinejoin="round" />
    </svg>
  );
};

export const Ghosts: React.FC<{t: number}> = ({t}) => (
  <>
    {DRAGS.map((d, i) => {
      if (t < d.from || t > d.to + 0.25) return null;
      const lagged = cursorAt(t - 0.05);
      const grab = easeOut(clamp01((t - d.from) / 0.15));
      const drop = easeIn(clamp01((t - d.to) / 0.22));
      const size = 52 * UI;
      const scale = (0.85 + 0.15 * grab) * (1 - 0.65 * drop);
      const count = d.files.length;
      return (
        <div key={i} style={{...abs(lagged.x + 4, lagged.y + 14), width: size, opacity: 0.85 * grab * (1 - drop),
          transform: `scale(${scale})`, transformOrigin: '0 0', fontFamily: FONT}}>
          {d.files.slice().reverse().map((f, k) => (
            <div key={f.name} style={{position: k === count - 1 ? 'relative' : 'absolute', left: (count - 1 - k) * 10,
              top: (count - 1 - k) * -8}}>
              <FileIcon kind={f.kind} size={size} id={`ghost-${i}-${k}`} />
            </div>
          ))}
          {count > 1 && (
            <div style={{position: 'absolute', right: -14, top: -16, minWidth: 32, height: 32, borderRadius: 16,
              background: C.red, color: '#fff', fontSize: 19, fontWeight: 700, display: 'flex', alignItems: 'center',
              justifyContent: 'center', boxShadow: '0 2px 6px rgba(0,0,0,0.4)'}}>
              {count}
            </div>
          )}
        </div>
      );
    })}
  </>
);

// ---- Key cap ----------------------------------------------------------------------------------

const Cap: React.FC<{label: string; lit: boolean; pressed: number; size: number}> = ({label, lit, pressed, size}) => (
  <div style={{padding: `${size * 0.32}px ${size * 0.9}px`, borderRadius: size * 0.5, fontFamily: FONT, fontSize: size,
    fontWeight: 600, lineHeight: 1, whiteSpace: 'nowrap', transform: `scale(${1 - 0.06 * pressed})`,
    background: lit ? C.highlight : 'rgba(255,255,255,0.13)', color: lit ? '#000' : 'rgba(255,255,255,0.8)',
    boxShadow: lit ? '0 6px 24px rgba(168,214,58,0.35)' : '0 4px 14px rgba(0,0,0,0.3)',
    border: lit ? '1px solid transparent' : '1px solid rgba(255,255,255,0.12)'}}>
    {label}
  </div>
);

export const KeyCap: React.FC<{t: number}> = ({t}) => {
  const w = keyCapActive(t);
  if (!w) return null;
  const vis = windowed(t, w.tap - 0.6, w.drop + 0.7, 0.25);
  const pressed = t >= w.tap && t < w.tap + 0.2 ? Math.sin(((t - w.tap) / 0.2) * Math.PI) : 0;
  return (
    <div style={{position: 'absolute', left: 0, right: 0, bottom: 70, display: 'flex', justifyContent: 'center',
      opacity: vis, transform: `translateY(${(1 - vis) * 16}px)`}}>
      <Cap label={w.key} lit={t >= w.tap} pressed={pressed} size={30} />
    </div>
  );
};

/** Small ⌘ next to the cursor during the Cmd-click that adds the second invoice to the selection. */
export const CmdClick: React.FC<{t: number}> = ({t}) => {
  const a = 24.45;
  const b = 25.15;
  if (t < a || t > b) return null;
  const {x, y} = cursorAt(t);
  const vis = windowed(t, a, b, 0.12);
  return (
    <div style={{...abs(x + 30, y - 52), opacity: vis, transform: `scale(${0.9 + 0.1 * vis})`}}>
      <Cap label="⌘" lit pressed={t > 24.7 && t < 24.85 ? 1 : 0} size={22} />
    </div>
  );
};

// ---- Captions --------------------------------------------------------------------------------

export const Captions: React.FC<{t: number}> = ({t}) => (
  <>
    {CAPTIONS.map((c) => {
      const vis = windowed(t, c.from, c.to, 0.3);
      if (vis <= 0) return null;
      return (
        <div key={c.title} style={{...abs(FINDER_LEFT, 80), opacity: vis, transform: `translateY(${(1 - vis) * 12}px)`,
          fontFamily: FONT, color: '#fff'}}>
          <div style={{fontSize: 50, fontWeight: 700, letterSpacing: -0.5}}>
            <span style={{color: C.lime}}>{c.title}</span>
          </div>
          <div style={{fontSize: 32, fontWeight: 500, color: 'rgba(255,255,255,0.78)', marginTop: 4}}>{c.text}</div>
        </div>
      );
    })}
  </>
);
const FINDER_LEFT = 132;

// ---- Trash (keep or replace) -----------------------------------------------------------------

export const Trash: React.FC<{t: number}> = ({t}) => {
  const vis = windowed(t, TRASH.from, TRASH.to, 0.35);
  if (vis <= 0) return null;
  const land = TRASH.docxFly + 0.7;
  const bump = t > land && t < land + 0.4 ? Math.sin(((t - land) / 0.4) * Math.PI) : 0;
  const fly = prog(t, TRASH.docxFly, land, easeInOut);
  const start = rowIconCenter('Report.docx', TRASH.docxFly);
  const end = {x: TRASH.x, y: TRASH.y - 40};
  const fx = lerp(start.x, end.x, fly);
  const fy = lerp(start.y, end.y, fly) - Math.sin(fly * Math.PI) * 220;
  return (
    <>
      <div style={{...abs(TRASH.x - 60, TRASH.y - 60), opacity: vis, transform: `scale(${(0.8 + 0.2 * vis) * (1 + 0.08 * bump)})`}}>
        <svg width="120" height="130" viewBox="0 0 120 130">
          <defs>
            <linearGradient id="bin" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor="rgba(255,255,255,0.32)" />
              <stop offset="1" stopColor="rgba(255,255,255,0.14)" />
            </linearGradient>
          </defs>
          <g transform={`translate(0 ${-bump * 8}) rotate(${-bump * 8} 20 26)`}>
            <rect x="14" y="20" width="92" height="10" rx="5" fill="rgba(255,255,255,0.55)" />
          </g>
          <path d="M22 36 H98 L91 120 a6 6 0 0 1 -6 5 H35 a6 6 0 0 1 -6 -5 Z" fill="url(#bin)"
            stroke="rgba(255,255,255,0.35)" strokeWidth="1.5" />
          {[42, 60, 78].map((x) => (
            <line key={x} x1={x} y1="46" x2={x + (x - 60) * 0.05} y2="114" stroke="rgba(255,255,255,0.3)" strokeWidth="3" strokeLinecap="round" />
          ))}
        </svg>
      </div>
      {t >= TRASH.docxFly && t < land + 0.05 && (
        <div style={{...abs(fx - 24, fy - 24), transform: `scale(${1.4 - 0.7 * fly}) rotate(${fly * 25}deg)`,
          opacity: 1 - prog(t, land - 0.1, land + 0.05)}}>
          <FileIcon kind="docx" size={48} id="fly-docx" />
        </div>
      )}
    </>
  );
};

// ---- Merge: pages fan out --------------------------------------------------------------------

export const PageFan: React.FC<{t: number}> = ({t}) => {
  if (t < FAN.from || t > FAN.to + 0.1) return null;
  const w = WHEELS[2];
  const appear = springy(t - FAN.from, 0.5);
  const fan = prog(t, FAN.from + 0.35, FAN.from + 0.95, easeOut) * (1 - prog(t, FAN.to - 0.75, FAN.to - 0.35));
  const leave = prog(t, FAN.to - 0.4, FAN.to, easeIn);
  const target = rowIconCenter('Merged.pdf', FAN.to);
  const cx = lerp(w.x, target.x, leave);
  const cy = lerp(w.y, target.y, leave) - Math.sin(leave * Math.PI) * 120;
  return (
    <div style={{...abs(cx, cy), opacity: Math.min(clamp01((t - FAN.from) / 0.15), 1 - leave * 0.9),
      transform: `scale(${(0.6 + 0.4 * appear) * (1 - 0.8 * leave)})`}}>
      {['Invoice March', 'Invoice April'].map((title, i) => {
        const side = i === 0 ? -1 : 1;
        return (
          <div key={title} style={{position: 'absolute', left: -90 + side * 100 * fan, top: -120,
            width: 180, height: 240, borderRadius: 10, background: '#F6F6F3', fontFamily: FONT,
            transform: `rotate(${side * 9 * fan}deg)`, boxShadow: '0 16px 40px rgba(0,0,0,0.45)', padding: 18,
            boxSizing: 'border-box', color: '#222'}}>
            <div style={{fontSize: 17, fontWeight: 700}}>{title}</div>
            {[0, 1, 2, 3, 4].map((k) => (
              <div key={k} style={{height: 7, borderRadius: 4, background: '#D7D9DD', marginTop: 14, width: `${[90, 70, 84, 60, 40][k]}%`}} />
            ))}
            <div style={{position: 'absolute', bottom: 12, left: 0, right: 0, textAlign: 'center', fontSize: 16,
              fontWeight: 700, color: '#7A9F27'}}>{i + 1}</div>
          </div>
        );
      })}
    </div>
  );
};

// ---- Strip metadata: info card ---------------------------------------------------------------

export const MetaCard: React.FC<{t: number}> = ({t}) => {
  if (t < META.from || t > META.to + 0.4) return null;
  const w = WHEELS[3];
  const vis = windowed(t, META.from, META.to + 0.4, 0.35);
  const strike = prog(t, META.strike, META.strike + 0.45, easeInOut);
  const gone = prog(t, META.strike + 0.55, META.strike + 0.9);
  const ok = prog(t, META.strike + 0.75, META.strike + 1.05, easeOut);
  const lines = ['📍 Zürich, Switzerland', '📱 iPhone 16 · Aug 12, 2026'];
  return (
    <div style={{...abs(w.x - 260, w.y - 95), width: 520, height: 190, borderRadius: 22, display: 'flex', gap: 22,
      alignItems: 'center', padding: 22, boxSizing: 'border-box', fontFamily: FONT, opacity: vis,
      transform: `translateY(${(1 - vis) * 14}px) scale(${0.96 + 0.04 * vis})`,
      background: 'rgba(32,34,30,0.96)', boxShadow: '0 24px 60px rgba(0,0,0,0.5), 0 0 0 1px rgba(255,255,255,0.08)'}}>
      <div style={{width: 146, height: 146, borderRadius: 14, overflow: 'hidden', flexShrink: 0}}>
        <svg width="146" height="146" viewBox="0 0 64 64">
          <defs>
            <linearGradient id="meta-sky" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor="#7CC6F2" />
              <stop offset="1" stopColor="#F6C98A" />
            </linearGradient>
          </defs>
          <rect width="64" height="64" fill="url(#meta-sky)" />
          <circle cx="46" cy="18" r="6" fill="#FFF3C4" />
          <path d="M0 64 L0 46 L18 26 L30 40 L40 30 L64 52 L64 64 Z" fill="#3E6B4A" />
        </svg>
      </div>
      <div style={{position: 'relative', flex: 1, height: 120}}>
        <div style={{color: '#fff', fontSize: 23, fontWeight: 700}}>Vacation.jpg</div>
        <div style={{opacity: 1 - gone}}>
          {lines.map((l, i) => (
            <div key={l} style={{position: 'relative', marginTop: 12, fontSize: 21, color: 'rgba(255,255,255,0.8)', width: 'max-content'}}>
              {l}
              <div style={{position: 'absolute', left: -4, top: '52%', height: 3, borderRadius: 2, background: C.red,
                width: `calc(${clamp01(strike * 1.4 - i * 0.4) * 100}% + 8px)`}} />
            </div>
          ))}
        </div>
        <div style={{position: 'absolute', top: 46, opacity: ok, transform: `translateY(${(1 - ok) * 8}px)`,
          fontSize: 23, fontWeight: 600, color: C.lime}}>✓ No location, no camera data</div>
      </div>
    </div>
  );
};

// ---- Float window ----------------------------------------------------------------------------

export const FloatWindow: React.FC<{t: number}> = ({t}) => {
  if (t < FLOAT.appear) return null;
  // Like FloatPanel.show: top-left corner 40 pt right of and 80 pt above the mouse.
  const mouse = cursorAt(WHEELS[4].drop);
  const start = {x: mouse.x + 40 * UI, y: mouse.y - 80 * UI};
  const move = prog(t, FLOAT.appear + 0.15, FLOAT.appear + 0.95, easeInOut);
  const pop = springy(t - FLOAT.appear, 0.45);
  const x = lerp(start.x, FLOAT.x, move);
  const y = lerp(start.y, FLOAT.y, move) - Math.sin(move * Math.PI) * 40;
  const fade = 1 - prog(t, 44.0, 44.6);
  return (
    <div style={{...abs(x, y), width: FLOAT.w, height: FLOAT.h, borderRadius: 14, overflow: 'hidden', opacity: fade * clamp01(pop * 2),
      transform: `scale(${0.7 + 0.3 * pop})`, transformOrigin: 'top left', fontFamily: FONT,
      background: 'rgba(38,40,36,0.92)', boxShadow: '0 24px 60px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.12)'}}>
      <div style={{height: 34, display: 'flex', alignItems: 'center', padding: '0 12px', gap: 10,
        background: 'rgba(255,255,255,0.06)', color: 'rgba(255,255,255,0.85)', fontSize: 15, fontWeight: 600}}>
        <div style={{width: 12, height: 12, borderRadius: 6, background: 'rgba(255,255,255,0.35)'}} />
        <span style={{whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis'}}>Screen Recording.mov</span>
      </div>
      <div style={{position: 'absolute', left: 22, right: 22, top: 56, bottom: 22, borderRadius: 8, overflow: 'hidden',
        background: 'linear-gradient(160deg, #2D3B4A, #1B222B)', display: 'flex', alignItems: 'center', justifyContent: 'center'}}>
        <div style={{position: 'absolute', left: 12, top: 12, right: 40, height: 10, borderRadius: 5, background: 'rgba(255,255,255,0.18)'}} />
        <div style={{position: 'absolute', left: 12, top: 32, width: 70, height: 50, borderRadius: 6, background: 'rgba(168,214,58,0.55)'}} />
        <div style={{width: 52, height: 52, borderRadius: 26, background: 'rgba(0,0,0,0.45)', display: 'flex',
          alignItems: 'center', justifyContent: 'center'}}>
          <svg width="22" height="22" viewBox="0 0 10 10"><path d="M2.5 1.5 L8.5 5 L2.5 8.5 Z" fill="#fff" /></svg>
        </div>
      </div>
    </div>
  );
};
