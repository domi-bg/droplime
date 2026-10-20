import {Easing} from 'remotion';

export const WIDTH = 1920;
export const HEIGHT = 1080;
export const FPS = 60;
export const DURATION = 50; // seconds

export const C = {
  bgTop: '#2A3326',
  bgBottom: '#161A14',
  lime: '#A8D63A',
  highlight: '#C9EB6A',
  red: '#FF2D3A',
  segment: 'rgba(31,31,31,0.9)',
  replace: 'rgba(61,28,28,0.92)',
  text: '#FFFFFF',
};

export const FONT = '-apple-system, "SF Pro Display", "SF Pro Text", "Helvetica Neue", Inter, sans-serif';

/** Scale of all "screen" UI (wheel, Finder, cursor) relative to macOS points. */
export const UI = 1.4;

export const clamp01 = (x: number) => Math.min(1, Math.max(0, x));
export const easeInOut = Easing.bezier(0.45, 0, 0.25, 1);
export const easeOut = Easing.bezier(0.16, 1, 0.3, 1);
export const easeIn = Easing.bezier(0.5, 0, 0.75, 0);

/** Eased progress of time t (seconds) between a and b. */
export const prog = (t: number, a: number, b: number, ease: (x: number) => number = easeInOut) =>
  ease(clamp01((t - a) / (b - a)));

/** 0 → 1 → 0 window: fades in over `fade` after a, out over `fade` before b. */
export const windowed = (t: number, a: number, b: number, fade = 0.3) =>
  Math.min(prog(t, a, a + fade, easeOut), 1 - prog(t, b - fade, b, easeIn));

export const lerp = (a: number, b: number, p: number) => a + (b - a) * p;

/** Damped overshoot 0 → 1 (like a spring), for t in seconds since start. */
export const springy = (t: number, duration = 0.45) => {
  if (t <= 0) return 0;
  if (t >= duration) return 1;
  const x = t / duration;
  return 1 - Math.exp(-6 * x) * Math.cos(x * Math.PI * 2.2) * (1 - x);
};
