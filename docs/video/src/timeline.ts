// Every moment of the video, in seconds. Scenes follow docs/demo-video.md.
import {clamp01, easeInOut, easeOut, prog} from './theme';

export type FileKind = 'heic' | 'jpg' | 'docx' | 'pdf' | 'mov' | 'png' | 'wav';

export interface Row {
  name: string;
  kind: FileKind;
  size: string;
  type: string;
  /** When the row slides into the list (new files). */
  appearAt?: number;
  /** When the row leaves the list (moved to Trash). */
  removeAt?: number;
}

// ---- Scene boundaries -------------------------------------------------------------------------

export const T = {
  introEnd: 4,
  finderIn: 4,
  finderOut: 44,
  outroIcon: 44.5,
};

// ---- Wheels -----------------------------------------------------------------------------------

export interface Wheel {
  title: string;
  items: string[];
  split: boolean;
  key: string;
  /** Wheel center = cursor position when the key is tapped. */
  x: number;
  y: number;
  /** Key tap; the wheel opens right after it. */
  tap: number;
  /** Drop on a segment. */
  drop: number;
  /** The picked item (for the ✓ in the middle). */
  picked: string;
}

const WX = 1390;
const WY = 560;

export const WHEELS: Wheel[] = [
  {title: 'Convert', items: ['JPG', 'PNG', 'TIFF', 'GIF', 'BMP', 'PDF'], split: false, key: '⇧ Shift',
    x: WX, y: WY, tap: 8.6, drop: 11.4, picked: 'JPG'},
  {title: 'Convert', items: ['PDF', 'RTF', 'HTML', 'TXT', 'ODT'], split: true, key: '⇧ Shift',
    x: WX, y: WY + 20, tap: 16.4, drop: 21.4, picked: 'PDF'},
  {title: 'Tools', items: ['Merge', 'ZIP'], split: false, key: '⌘ Cmd',
    x: WX, y: WY, tap: 26.6, drop: 28.8, picked: 'Merge'},
  {title: 'Tools', items: ['Resize', 'Rotate', 'Strip Metadata', 'ZIP'], split: false, key: '⌘ Cmd',
    x: WX, y: WY, tap: 33.5, drop: 35.3, picked: 'Strip Metadata'},
  {title: 'Actions', items: ['AirDrop', 'Copy', 'Move', 'Path', 'Terminal', 'Float'], split: false, key: '⌃ Ctrl',
    x: WX, y: WY, tap: 39.4, drop: 41.0, picked: 'Float'},
];

export const WHEEL_OPEN_DELAY = 0.08;
/** The app hides the wheel 0.4 s after a drop. */
export const WHEEL_HIDE_DELAY = 0.4;

// ---- Finder ------------------------------------------------------------------------------------

export const ROWS: Row[] = [
  {name: 'Interview.wav', kind: 'wav', size: '31.7 MB', type: 'Waveform audio'},
  {name: 'Invoice April.pdf', kind: 'pdf', size: '98 KB', type: 'PDF document'},
  {name: 'Invoice March.pdf', kind: 'pdf', size: '112 KB', type: 'PDF document'},
  {name: 'Logo.png', kind: 'png', size: '64 KB', type: 'PNG image'},
  {name: 'Merged.pdf', kind: 'pdf', size: '210 KB', type: 'PDF document', appearAt: 30.75},
  {name: 'Report.docx', kind: 'docx', size: '86 KB', type: 'Word document', removeAt: 22.0},
  {name: 'Report.pdf', kind: 'pdf', size: '142 KB', type: 'PDF document', appearAt: 21.8},
  {name: 'Screen Recording.mov', kind: 'mov', size: '48.3 MB', type: 'QuickTime movie'},
  {name: 'Vacation (no metadata).jpg', kind: 'jpg', size: '3.0 MB', type: 'JPEG image', appearAt: 35.8},
  {name: 'Vacation.heic', kind: 'heic', size: '2.4 MB', type: 'HEIF image'},
  {name: 'Vacation.jpg', kind: 'jpg', size: '3.1 MB', type: 'JPEG image', appearAt: 11.9},
];

export const FINDER = {x: 130, y: 230, w: 960, rowH: 52, titleH: 64, headerH: 40, sidebar: 210};
export const FINDER_H = FINDER.titleH + FINDER.headerH + FINDER.rowH * 10 + 16;

const ROW_IN = 0.55;
const ROW_OUT = 0.45;

/** How much of a row's slot is taken (0 … 1), so the other rows make room smoothly. */
export const presence = (row: Row, t: number) => {
  let p = 1;
  if (row.appearAt !== undefined) p = Math.min(p, prog(t, row.appearAt, row.appearAt + ROW_IN));
  if (row.removeAt !== undefined) p = Math.min(p, 1 - prog(t, row.removeAt + 0.25, row.removeAt + 0.25 + ROW_OUT));
  return p;
};

/** Continuous row index (sorted by name), animated while rows come and go. */
export const slot = (name: string, t: number) => {
  let s = 0;
  for (const r of ROWS) {
    if (r.name === name) return s;
    s += presence(r, t);
  }
  return s;
};

export const rowTop = (name: string, t: number) =>
  FINDER.y + FINDER.titleH + FINDER.headerH + 8 + slot(name, t) * FINDER.rowH;

/** Point on a row's icon/name, where the cursor grabs it. */
export const rowGrab = (name: string, t: number) => ({x: FINDER.x + FINDER.sidebar + 80, y: rowTop(name, t) + FINDER.rowH / 2 + 4});

// ---- Selection ---------------------------------------------------------------------------------

export const SELECTIONS: {name: string; from: number; to: number}[] = [
  {name: 'Vacation.heic', from: 7.0, to: 11.6},
  {name: 'Report.docx', from: 14.9, to: 21.6},
  {name: 'Invoice March.pdf', from: 24.2, to: 30.0},
  {name: 'Invoice April.pdf', from: 24.9, to: 30.0},
  {name: 'Vacation.jpg', from: 31.9, to: 36.4},
  {name: 'Screen Recording.mov', from: 37.9, to: 41.6},
];

export const selected = (name: string, t: number) =>
  SELECTIONS.some((s) => s.name === name && t >= s.from && t < s.to);

// ---- Cursor ------------------------------------------------------------------------------------

interface Waypoint {
  t: number;
  x: number;
  y: number;
  /** Sideways bend of the arc leading to this point (fraction of the distance). */
  bend?: number;
}

const W = (i: number) => WHEELS[i];
/**
 * Point on segment `index` of wheel `w` at the given radius (app points), shifted right by `dx` px
 * so the label stays readable left of the cursor while the dragged file hangs below-right.
 */
export const onSegment = (w: Wheel, index: number, radius: number, dx = 0) => {
  const step = 360 / w.items.length;
  const a = ((90 - index * step) * Math.PI) / 180;
  return {x: w.x + Math.cos(a) * radius * 1.4 + dx, y: w.y - Math.sin(a) * radius * 1.4 - 6};
};

const g = rowGrab;

export const WAYPOINTS: Waypoint[] = [
  {t: 0, x: 1760, y: 1180},
  {t: 5.0, x: 1760, y: 1180},
  {t: 6.6, ...g('Vacation.heic', 6.6), bend: 0.12},
  // Convert
  {t: 7.1, ...g('Vacation.heic', 7.1)},
  {t: 8.4, x: W(0).x, y: W(0).y, bend: -0.18},
  {t: 8.85, x: W(0).x, y: W(0).y},
  {t: 9.9, ...onSegment(W(0), 0, 108, 52), bend: 0.25},
  {t: 11.4, ...onSegment(W(0), 0, 112, 50), bend: 0},
  {t: 12.2, ...onSegment(W(0), 0, 112, 50)},
  {t: 14.4, ...g('Report.docx', 14.4), bend: 0.14},
  // Keep or replace
  {t: 14.9, ...g('Report.docx', 14.9)},
  {t: 16.2, x: W(1).x, y: W(1).y, bend: -0.16},
  {t: 16.7, x: W(1).x, y: W(1).y},
  {t: 17.6, ...onSegment(W(1), 0, 92, 60), bend: 0.2},
  {t: 19.2, ...onSegment(W(1), 0, 96, 59), bend: 0},
  {t: 20.0, ...onSegment(W(1), 0, 164, 59), bend: 0},
  {t: 21.4, ...onSegment(W(1), 0, 166, 58), bend: 0},
  {t: 22.4, ...onSegment(W(1), 0, 166, 58)},
  {t: 23.8, ...g('Invoice March.pdf', 23.8), bend: -0.12},
  // Merge: click, cmd-click, drag both
  {t: 24.2, ...g('Invoice March.pdf', 24.2)},
  {t: 24.75, ...g('Invoice April.pdf', 24.75), bend: 0.3},
  {t: 25.1, ...g('Invoice April.pdf', 25.1)},
  {t: 26.4, x: W(2).x, y: W(2).y, bend: -0.16},
  {t: 26.85, x: W(2).x, y: W(2).y},
  {t: 27.8, ...onSegment(W(2), 0, 104, 65), bend: 0.25},
  {t: 28.8, ...onSegment(W(2), 0, 108, 64), bend: 0},
  {t: 29.3, ...onSegment(W(2), 0, 108, 64)},
  {t: 30.0, x: 1720, y: 290, bend: 0.1},
  {t: 30.6, x: 1720, y: 290},
  {t: 31.6, ...g('Vacation.jpg', 31.6), bend: -0.12},
  // Strip metadata
  {t: 31.95, ...g('Vacation.jpg', 31.95)},
  {t: 33.3, x: W(3).x, y: W(3).y, bend: -0.16},
  {t: 33.75, x: W(3).x, y: W(3).y},
  {t: 34.7, ...onSegment(W(3), 2, 104, 96), bend: 0.22},
  {t: 35.3, ...onSegment(W(3), 2, 108, 97), bend: 0},
  {t: 35.6, ...onSegment(W(3), 2, 108, 97)},
  {t: 37.5, ...g('Screen Recording.mov', 37.5), bend: -0.12},
  // Float
  {t: 37.95, ...g('Screen Recording.mov', 37.95)},
  {t: 39.2, x: W(4).x, y: W(4).y, bend: -0.16},
  {t: 39.65, x: W(4).x, y: W(4).y},
  {t: 40.5, ...onSegment(W(4), 5, 104, 60), bend: 0.22},
  {t: 41.0, ...onSegment(W(4), 5, 108, 59), bend: 0},
  {t: 41.9, ...onSegment(W(4), 5, 108, 59)},
  {t: 42.6, x: 1640, y: 300, bend: -0.2},
  {t: 42.85, x: 1640, y: 300},
  {t: 43.9, x: 1250, y: 720, bend: 0.18},
  {t: 44.4, x: 1250, y: 720},
  {t: 45.4, x: 1780, y: 1200, bend: -0.1},
  {t: 60, x: 1780, y: 1200},
];

export const cursorAt = (t: number) => {
  let i = 0;
  while (i < WAYPOINTS.length - 2 && WAYPOINTS[i + 1].t <= t) i++;
  const a = WAYPOINTS[i];
  const b = WAYPOINTS[i + 1];
  const p = easeInOut(clamp01((t - a.t) / (b.t - a.t)));
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const bend = b.bend ?? 0.12;
  // Quadratic Bézier with the control point pushed sideways: a soft arc instead of a straight line.
  const cx = a.x + dx / 2 - dy * bend;
  const cy = a.y + dy / 2 + dx * bend;
  const q = 1 - p;
  return {x: q * q * a.x + 2 * q * p * cx + p * p * b.x, y: q * q * a.y + 2 * q * p * cy + p * p * b.y};
};

/** Mouse-button presses (for the small squeeze of the cursor). */
export const CLICKS = [7.1, 14.9, 24.2, 24.75, 31.95, 37.95, 42.85];

// ---- Drags -------------------------------------------------------------------------------------

export interface Drag {
  files: {name: string; kind: FileKind}[];
  from: number;
  /** Drop time; the ghost shrinks into the wheel. */
  to: number;
}

export const DRAGS: Drag[] = [
  {files: [{name: 'Vacation.heic', kind: 'heic'}], from: 7.2, to: W(0).drop},
  {files: [{name: 'Report.docx', kind: 'docx'}], from: 15.0, to: W(1).drop},
  {files: [{name: 'Invoice March.pdf', kind: 'pdf'}, {name: 'Invoice April.pdf', kind: 'pdf'}], from: 25.2, to: W(2).drop},
  {files: [{name: 'Vacation.jpg', kind: 'jpg'}], from: 32.05, to: W(3).drop},
  {files: [{name: 'Screen Recording.mov', kind: 'mov'}], from: 38.05, to: W(4).drop},
  {files: [{name: 'Screen Recording.mov', kind: 'mov'}], from: 42.95, to: 44.4},
];

// ---- Captions ----------------------------------------------------------------------------------

export const CAPTIONS: {title: string; text: string; from: number; to: number}[] = [
  {title: 'Convert', text: 'Only formats that fit.', from: 7.3, to: 14.4},
  {title: 'Inside', text: 'keep the original', from: 17.4, to: 19.7},
  {title: 'Outside', text: 'original to Trash', from: 19.8, to: 23.6},
  {title: 'Tools', text: 'Two PDFs → one.', from: 24.4, to: 31.4},
  {title: 'Strip Metadata', text: 'Location gone, photo stays.', from: 32.0, to: 37.4},
  {title: 'Float', text: 'Park files, drag them on later.', from: 38.1, to: 43.9},
];

// ---- Extras ------------------------------------------------------------------------------------

export const TRASH = {x: 1780, y: 930, from: 20.0, to: 23.6, docxFly: 22.0};
export const FLOAT = {appear: 41.35, x: 1580, y: 210, w: 168 * 1.4, h: 176 * 1.4, pull: 42.95};
export const FAN = {from: 29.2, to: 31.2};
export const META = {from: 35.35, strike: 35.9, to: 37.2};

export const keyCapActive = (t: number) => WHEELS.find((w) => t > w.tap - 0.6 && t < w.drop + 0.7);

export {easeOut};
