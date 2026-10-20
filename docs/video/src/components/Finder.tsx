import {FONT, clamp01, easeOut, prog} from '../theme';
import {FINDER, FINDER_H, ROWS, TRASH, presence, rowTop, selected} from '../timeline';
import {FileIcon} from './FileIcon';

const ICON = 34;

const Sidebar: React.FC = () => (
  <div style={{width: FINDER.sidebar, padding: '14px 12px', boxSizing: 'border-box', color: 'rgba(255,255,255,0.5)',
    fontSize: 15, fontWeight: 600, background: 'rgba(255,255,255,0.03)', borderRight: '1px solid rgba(255,255,255,0.06)'}}>
    <div style={{padding: '6px 10px'}}>Favorites</div>
    {['Desktop', 'Documents', 'Downloads', 'Project'].map((name) => (
      <div key={name} style={{display: 'flex', alignItems: 'center', gap: 10, padding: '8px 10px', borderRadius: 8,
        color: '#fff', fontSize: 18, fontWeight: 500,
        background: name === 'Project' ? 'rgba(255,255,255,0.1)' : 'transparent'}}>
        <svg width="20" height="16" viewBox="0 0 20 16">
          <path d="M1 3 a2 2 0 0 1 2 -2 H7 l2 2 H17 a2 2 0 0 1 2 2 V13 a2 2 0 0 1 -2 2 H3 a2 2 0 0 1 -2 -2 Z"
            fill="none" stroke="#A8D63A" strokeWidth="1.6" />
        </svg>
        {name}
      </div>
    ))}
  </div>
);

export const Finder: React.FC<{t: number}> = ({t}) => {
  const appear = prog(t, 4.0, 4.7, easeOut);
  const leave = prog(t, 44.0, 44.6);
  const opacity = appear * (1 - leave);
  if (opacity <= 0) return null;
  const listTop = FINDER.y + FINDER.titleH + FINDER.headerH + 8;

  return (
    <div style={{position: 'absolute', left: FINDER.x, top: FINDER.y, width: FINDER.w, height: FINDER_H, opacity,
      transform: `translateY(${(1 - appear) * 30 + leave * 20}px) scale(${0.97 + 0.03 * appear})`,
      borderRadius: 16, overflow: 'hidden', background: '#1F201E', fontFamily: FONT,
      boxShadow: '0 30px 80px rgba(0,0,0,0.5), 0 0 0 1px rgba(255,255,255,0.08)'}}>
      {/* Title bar */}
      <div style={{height: FINDER.titleH, display: 'flex', alignItems: 'center', padding: '0 22px', gap: 10,
        borderBottom: '1px solid rgba(0,0,0,0.5)', background: '#2A2B28'}}>
        {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => (
          <div key={c} style={{width: 15, height: 15, borderRadius: 8, background: c}} />
        ))}
        <div style={{marginLeft: FINDER.sidebar - 100, display: 'flex', gap: 22, color: 'rgba(255,255,255,0.45)', fontSize: 24}}>
          <span>‹</span>
          <span>›</span>
        </div>
        <div style={{marginLeft: 18, color: '#fff', fontSize: 21, fontWeight: 700}}>Project</div>
      </div>
      <div style={{display: 'flex', height: FINDER_H - FINDER.titleH}}>
        <Sidebar />
        <div style={{flex: 1, position: 'relative'}}>
          {/* Column header */}
          <div style={{height: FINDER.headerH, display: 'flex', alignItems: 'center', color: 'rgba(255,255,255,0.5)',
            fontSize: 15, fontWeight: 600, borderBottom: '1px solid rgba(255,255,255,0.07)'}}>
            <div style={{width: 430, paddingLeft: 22}}>Name</div>
            <div style={{width: 110}}>Size</div>
            <div>Kind</div>
          </div>
          {/* Zebra stripes stay put; the rows move over them. */}
          {Array.from({length: 10}, (_, i) => (
            <div key={i} style={{position: 'absolute', left: 8, right: 8, top: FINDER.headerH + 8 + i * FINDER.rowH,
              height: FINDER.rowH, borderRadius: 8, background: i % 2 ? 'rgba(255,255,255,0.025)' : 'transparent'}} />
          ))}
          {ROWS.map((row) => {
            const p = presence(row, t);
            if (p <= 0.001 && (row.removeAt === undefined || t < row.removeAt)) return null;
            const top = rowTop(row.name, t) - listTop + FINDER.headerH + 8;
            const removing = row.removeAt !== undefined ? prog(t, TRASH.docxFly - 0.05, TRASH.docxFly + 0.25) : 0;
            const arrived = row.appearAt !== undefined ? t - row.appearAt - 0.35 : -1;
            const glow = arrived > 0 ? Math.sin(Math.min(1, arrived / 1.6) * Math.PI) ** 0.7 : 0;
            const sel = selected(row.name, t);
            const iconGone = row.removeAt !== undefined && t >= TRASH.docxFly;
            return (
              <div key={row.name} style={{position: 'absolute', left: 8, right: 8, top, height: FINDER.rowH,
                display: 'flex', alignItems: 'center', borderRadius: 8, color: '#fff', fontSize: 20,
                opacity: Math.min(row.appearAt !== undefined ? clamp01(p * 1.4) : 1, 1 - removing),
                transform: `translateX(${(1 - p) * -18}px)`,
                background: sel ? 'rgba(168,214,58,0.26)' : `rgba(201,235,106,${0.42 * glow})`,
                boxShadow: glow > 0 ? `0 0 ${24 * glow}px rgba(168,214,58,${0.45 * glow})` : 'none'}}>
                <div style={{width: 422, display: 'flex', alignItems: 'center', gap: 14, paddingLeft: 14}}>
                  <div style={{opacity: iconGone ? 0 : 1}}><FileIcon kind={row.kind} size={ICON} id={`row-${row.name}`} /></div>
                  <span style={{whiteSpace: 'nowrap'}}>{row.name}</span>
                </div>
                <div style={{width: 110, color: 'rgba(255,255,255,0.55)', fontSize: 18}}>{row.size}</div>
                <div style={{color: 'rgba(255,255,255,0.55)', fontSize: 18, whiteSpace: 'nowrap'}}>{row.type}</div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};

/** Screen position of a row's icon center (for things that fly out of / into the list). */
export const rowIconCenter = (name: string, t: number) => ({
  x: FINDER.x + FINDER.sidebar + 8 + 14 + ICON / 2,
  y: rowTop(name, t) + FINDER.rowH / 2,
});
