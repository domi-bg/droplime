import type {FileKind} from '../timeline';

const BADGE: Record<FileKind, {color: string; label: string}> = {
  heic: {color: '#E8A33A', label: 'HEIC'},
  jpg: {color: '#3FA7E0', label: 'JPG'},
  png: {color: '#8D6BE8', label: 'PNG'},
  docx: {color: '#2F6BDE', label: 'DOCX'},
  pdf: {color: '#E5483C', label: 'PDF'},
  mov: {color: '#4A4F58', label: 'MOV'},
  wav: {color: '#E0457B', label: 'WAV'},
};

const isImage = (k: FileKind) => k === 'heic' || k === 'jpg' || k === 'png';

/** Simple flat document icon: page with folded corner, a preview and a colored type badge. */
export const FileIcon: React.FC<{kind: FileKind; size: number; id: string}> = ({kind, size, id: rawId}) => {
  const b = BADGE[kind];
  const id = rawId.replace(/[^A-Za-z0-9-]/g, '_');
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" style={{display: 'block', overflow: 'visible'}}>
      <defs>
        <linearGradient id={`sky-${id}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#7CC6F2" />
          <stop offset="1" stopColor="#F6C98A" />
        </linearGradient>
        <clipPath id={`page-${id}`}>
          <path d="M14 4 H40 L52 16 V58 a2 2 0 0 1 -2 2 H14 a2 2 0 0 1 -2 -2 V6 a2 2 0 0 1 2 -2 Z" />
        </clipPath>
      </defs>
      <path d="M14 4 H40 L52 16 V58 a2 2 0 0 1 -2 2 H14 a2 2 0 0 1 -2 -2 V6 a2 2 0 0 1 2 -2 Z"
        fill="#F4F4F2" stroke="rgba(0,0,0,0.25)" strokeWidth="0.8" />
      <g clipPath={`url(#page-${id})`}>
        {isImage(kind) ? (
          kind === 'png' ? (
            <g>
              <circle cx="32" cy="30" r="11" fill="#A8D63A" />
              <circle cx="32" cy="30" r="5" fill="#F4F4F2" />
            </g>
          ) : (
            <g>
              <rect x="12" y="10" width="40" height="34" fill={`url(#sky-${id})`} />
              <circle cx="40" cy="20" r="4" fill="#FFF3C4" />
              <path d="M12 44 L24 28 L32 37 L38 31 L52 44 Z" fill="#3E6B4A" />
            </g>
          )
        ) : kind === 'mov' ? (
          <g>
            <rect x="12" y="12" width="40" height="30" fill="#2B2F36" />
            <path d="M28 21 L38 27 L28 33 Z" fill="#fff" />
          </g>
        ) : kind === 'wav' ? (
          <g stroke="#E0457B" strokeWidth="2.4" strokeLinecap="round">
            {[18, 23, 28, 33, 38, 43, 48].map((x, i) => {
              const h = [5, 10, 15, 8, 13, 6, 3][i];
              return <line key={x} x1={x - 1} x2={x - 1} y1={28 - h} y2={28 + h} />;
            })}
          </g>
        ) : (
          <g fill="#C9CCD1">
            {[14, 20, 26, 32, 38].map((y) => (
              <rect key={y} x="18" y={y} width={y === 38 ? 16 : 28} height="2.6" rx="1.3" />
            ))}
          </g>
        )}
      </g>
      <path d="M40 4 V14 a2 2 0 0 0 2 2 H52 Z" fill="#DADAD6" />
      <rect x="10" y="46" width={b.label.length > 3 ? 32 : 26} height="11" rx="2.5" fill={b.color} />
      <text x={10 + (b.label.length > 3 ? 16 : 13)} y="54.6" textAnchor="middle" fontSize="8.4" fontWeight="800"
        fill="#fff" fontFamily="-apple-system, Helvetica, sans-serif">{b.label}</text>
    </svg>
  );
};
