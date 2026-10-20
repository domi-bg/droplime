// The Droplime symbol, ported from Sources/Droplime/LimeIcon.swift (1024 grid: radius 300,
// membrane 30, corner 24, popped segment 1 pulled out by 46).
const COUNT = 8;
const POPPED = 1;
const R = 300;
const MEMBRANE = 30;
const CORNER = 24;
const POP = 46;

const segmentPath = (i: number) => {
  const half = Math.PI / COUNT;
  const mid = Math.PI / 2 - i * 2 * half;
  const d = MEMBRANE / 2 + CORNER;
  const outer = R - CORNER;
  const t = Math.sqrt(outer * outer - d * d);
  const edge = (e: number, inward: number) => [
    Math.cos(e) * t + Math.cos(e + inward) * d,
    Math.sin(e) * t + Math.sin(e + inward) * d,
  ];
  const left = edge(mid + half, -Math.PI / 2);
  const right = edge(mid - half, Math.PI / 2);
  const apex = d / Math.sin(half);
  const ax = Math.cos(mid) * apex;
  const ay = Math.sin(mid) * apex;
  // Math coordinates (y up) → SVG (y down).
  return `M${ax} ${-ay} L${right[0]} ${-right[1]} A${outer} ${outer} 0 0 0 ${left[0]} ${-left[1]} Z`;
};

const dir = (i: number) => {
  const mid = Math.PI / 2 - (i * 2 * Math.PI) / COUNT;
  return [Math.cos(mid), -Math.sin(mid)];
};

/**
 * @param size  diameter of the lime in pixels
 * @param assemble  per segment 0 (far out, invisible) … 1 (in place)
 * @param pop  0 … 1 (≥1 with overshoot) how far the popped segment sticks out
 */
export const LimeMark: React.FC<{size: number; assemble?: (i: number) => number; pop?: number; id?: string}> = ({
  size,
  assemble = () => 1,
  pop = 1,
  id = 'lime',
}) => {
  return (
    <svg width={size} height={size} viewBox={`${-R - POP} ${-R - POP} ${2 * R + 2 * POP} ${2 * R + 2 * POP}`}
      style={{overflow: 'visible', display: 'block'}}>
      <defs>
        <radialGradient id={`${id}-rest`} cx="0" cy="0" r={R} gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="rgb(204,235,115)" />
          <stop offset="1" stopColor="rgb(128,189,41)" />
        </radialGradient>
        <radialGradient id={`${id}-pop`} cx="0" cy="0" r={R} gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="rgb(245,255,173)" />
          <stop offset="1" stopColor="rgb(184,230,61)" />
        </radialGradient>
        <filter id={`${id}-shadow`} x="-50%" y="-50%" width="200%" height="200%">
          <feDropShadow dx="0" dy="12" stdDeviation="15" floodColor="#000" floodOpacity={0.5 * Math.min(1, pop)} />
        </filter>
      </defs>
      {Array.from({length: COUNT}, (_, i) => {
        const p = assemble(i);
        const [dx, dy] = dir(i);
        const fly = (1 - p) * 520;
        const popped = i === POPPED;
        const out = popped ? POP * pop : 0;
        const tx = dx * (fly + out);
        const ty = dy * (fly + out);
        const fill = `url(#${id}-${popped && pop > 0.05 ? 'pop' : 'rest'})`;
        return (
          <g key={i} transform={`translate(${tx} ${ty}) rotate(${(1 - p) * (i % 2 ? 40 : -40)})`}
            opacity={Math.min(1, p * 1.6)}
            filter={popped ? `url(#${id}-shadow)` : undefined}>
            <path d={segmentPath(i)} fill={fill} stroke={fill} strokeWidth={CORNER * 2} strokeLinejoin="round" />
          </g>
        );
      })}
    </svg>
  );
};
