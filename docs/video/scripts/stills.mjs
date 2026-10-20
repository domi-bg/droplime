// Renders single frames for a quick visual check: node scripts/stills.mjs 2.5 10.5 …  (seconds)
import {bundle} from '@remotion/bundler';
import {renderStill, selectComposition} from '@remotion/renderer';
import path from 'node:path';

const serveUrl = await bundle({entryPoint: path.resolve('src/index.ts')});
const composition = await selectComposition({serveUrl, id: 'DemoSilent', inputProps: {sound: false}});
for (const s of process.argv.slice(2)) {
  const frame = Math.round(Number(s) * composition.fps);
  await renderStill({serveUrl, composition, frame, output: `out/stills/${s}s.png`, inputProps: {sound: false}});
  console.log('rendered', s);
}
