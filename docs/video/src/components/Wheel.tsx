import {FONT, UI, clamp01, easeIn, easeOut, springy} from '../theme';
import {WHEEL_HIDE_DELAY, WHEEL_OPEN_DELAY, type Wheel as WheelData} from '../timeline';

// Look and geometry from Sources/Droplime/WheelPanel.swift (in points; scaled by UI).
const INNER = 48;
const GAP = 6;
const CORNER = 9;
const POP = 8;
const LIME = 'rgb(176,219,69)';
const AMBER = 'rgb(250,189,69)';
const SEGMENT = 'rgb(33,33,33)';
const REPLACE = 'rgb(51,43,31)';

const dir = (deg: number) => [Math.cos((deg * Math.PI) / 180), -Math.sin((deg * Math.PI) / 180)] as const;

/**
 * Segment between r1 and r2, inset by the corner radius. Filled *and* stroked with 2 × CORNER
 * and round joins it grows back to full size with rounded corners and constant-width gaps.
 */
const corePath = (mid: number, step: number, r1: number, r2: number) => {
  const inner = r1 + CORNER;
  const outer = r2 - CORNER;
  const d = GAP / 2 + CORNER;
  const half = step / 2;
  const edge = (edgeDeg: number, sign: number, r: number) => {
    const t = Math.sqrt(Math.max(r * r - d * d, 0));
    const [ex, ey] = dir(edgeDeg);
    const [nx, ny] = dir(edgeDeg + sign * 90);
    return [ex * t + nx * d, ey * t + ny * d];
  };
  const oR = edge(mid - half, 1, outer);
  const oL = edge(mid + half, -1, outer);
  const iL = edge(mid + half, -1, inner);
  const iR = edge(mid - half, 1, inner);
  return `M${iR[0]} ${iR[1]} L${oR[0]} ${oR[1]} A${outer} ${outer} 0 0 0 ${oL[0]} ${oL[1]} L${iL[0]} ${iL[1]} A${inner} ${inner} 0 0 1 ${iR[0]} ${iR[1]} Z`;
};

/** Same hit test as WheelView.hit(at:), in video pixels relative to the wheel center. */
export const hitTest = (w: WheelData, dx: number, dy: number) => {
  const middle = w.split ? 128 : 150;
  const outer = w.split ? 190 : 150;
  const d = Math.hypot(dx, dy) / UI;
  if (d < INNER || d > outer) return null;
  const step = 360 / w.items.length;
  const theta = (Math.atan2(-dy, dx) * 180) / Math.PI;
  let deg = (90 - theta) % 360;
  if (deg < 0) deg += 360;
  return {index: Math.floor((deg + step / 2) / step) % w.items.length, outer: d > middle};
};

const Segment: React.FC<{d: string; fill: string; hit: boolean}> = ({d, fill, hit}) => (
  <g filter={`url(#${hit ? 'wheel-shadow-hit' : 'wheel-shadow'})`}>
    {!hit && <path d={d} fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth={CORNER * 2 + 2} strokeLinejoin="round" />}
    <g opacity={hit ? 1 : 0.94}>
      <path d={d} fill={fill} stroke={fill} strokeWidth={CORNER * 2} strokeLinejoin="round" />
    </g>
  </g>
);

/** SF Symbol "arrow.triangle.2.circlepath", redrawn. */
const Swap: React.FC<{x: number; y: number; color: string}> = ({x, y, color}) => (
  <g transform={`translate(${x} ${y})`} stroke={color} strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round">
    <path d="M-5.2 -1.2 A5.4 5.4 0 0 1 4.6 -2.6" />
    <path d="M5.2 1.2 A5.4 5.4 0 0 1 -4.6 2.6" />
    <path d="M2.4 -3.4 L4.8 -2.4 L5.6 -4.9" />
    <path d="M-2.4 3.4 L-4.8 2.4 L-5.6 4.9" />
  </g>
);

export const Wheel: React.FC<{w: WheelData; t: number; cursor: {x: number; y: number}}> = ({w, t, cursor}) => {
  const open = w.tap + WHEEL_OPEN_DELAY;
  const hide = w.drop + WHEEL_HIDE_DELAY;
  if (t < open || t > hide + 0.3) return null;

  const middle = w.split ? 128 : 150;
  const outer = w.split ? 190 : 150;
  const ringGap = w.split ? GAP / 2 : 0;
  const step = 360 / w.items.length;
  const dropped = t >= w.drop;
  const live = t > open + 0.2 && !dropped;
  const hit = live ? hitTest(w, cursor.x - w.x, cursor.y - w.y) : null;

  const collapse = easeIn(clamp01((t - hide) / 0.25));
  const discIn = springy(t - open, 0.4);
  // The highlighted segment is drawn last, so its shadow lies on its neighbours.
  const order = w.items.map((_, i) => i).filter((i) => i !== hit?.index).concat(hit ? [hit.index] : []);

  return (
    <svg width={1920} height={1080} style={{position: 'absolute', left: 0, top: 0, overflow: 'visible'}}>
      <defs>
        <filter id="wheel-shadow" x="-50%" y="-50%" width="200%" height="200%">
          <feDropShadow dx="0" dy="3" stdDeviation="4" floodColor="#000" floodOpacity="0.3" />
        </filter>
        <filter id="wheel-shadow-hit" x="-50%" y="-50%" width="200%" height="200%">
          <feDropShadow dx="0" dy="3" stdDeviation="7" floodColor="#000" floodOpacity="0.5" />
        </filter>
      </defs>
      <g transform={`translate(${w.x} ${w.y}) scale(${UI * (1 - collapse * 0.35)})`} opacity={1 - collapse} fontFamily={FONT}>
        {order.map((i) => {
          const item = w.items[i];
          const a = 90 - i * step;
          const local = springy(t - open - 0.03 - i * 0.025, 0.42);
          const fade = clamp01((t - open - i * 0.025) / 0.12);
          const innerHit = hit?.index === i && !hit.outer;
          const outerHit = hit?.index === i && hit.outer;
          const [ux, uy] = dir(a);
          const innerPop = innerHit ? POP : 0;
          const outerPop = outerHit ? POP : 0;
          const lr = (INNER + middle) / 2;
          const tr = (middle + outer) / 2;
          const innerColor = innerHit ? '#000' : '#fff';
          const outerColor = outerHit ? '#000' : AMBER;
          return (
            <g key={item} opacity={fade} transform={`scale(${0.55 + 0.45 * local})`}>
              <g transform={`translate(${ux * innerPop} ${uy * innerPop})`}>
                <Segment d={corePath(a, step, INNER, middle - ringGap)} fill={innerHit ? LIME : SEGMENT} hit={innerHit} />
                {w.split ? (
                  <>
                    <text x={ux * lr} y={uy * lr - 6} textAnchor="middle" dominantBaseline="central" fontSize="13"
                      fontWeight="600" fill={innerColor}>{item}</text>
                    <text x={ux * lr} y={uy * lr + 9} textAnchor="middle" dominantBaseline="central" fontSize="9"
                      fontWeight="500" fill={innerColor} fillOpacity={0.6}>Keep</text>
                  </>
                ) : (
                  <text x={ux * lr} y={uy * lr} textAnchor="middle" dominantBaseline="central" fontSize="13"
                    fontWeight="600" fill={innerColor}>{item}</text>
                )}
              </g>
              {w.split && (
                <g transform={`translate(${ux * outerPop} ${uy * outerPop})`}>
                  <Segment d={corePath(a, step, middle + ringGap, outer)} fill={outerHit ? AMBER : REPLACE} hit={outerHit} />
                  <Swap x={ux * tr} y={uy * tr - 7} color={outerColor} />
                  <text x={ux * tr} y={uy * tr + 9} textAnchor="middle" dominantBaseline="central" fontSize="9"
                    fontWeight="600" fill={outerColor}>Replace</text>
                </g>
              )}
            </g>
          );
        })}
        <g transform={`scale(${0.6 + 0.4 * discIn})`} opacity={clamp01((t - open) / 0.1)}>
          <g filter="url(#wheel-shadow)">
            <circle r={INNER - 4} fill="rgba(23,23,23,0.96)" stroke="rgba(255,255,255,0.08)" strokeWidth="1" />
          </g>
          <text textAnchor="middle" dominantBaseline="central" fontSize="10" fontWeight="600" fill="#fff"
            opacity={dropped ? easeOut(clamp01((t - w.drop) / 0.15)) : 1}>
            {dropped ? `✓ ${w.picked}` : w.title}
          </text>
        </g>
      </g>
    </svg>
  );
};
