import {Composition} from 'remotion';
import {Demo} from './Demo';
import {DURATION, FPS, HEIGHT, WIDTH} from './theme';

export const Root: React.FC = () => (
  <>
    <Composition id="Demo" component={Demo} durationInFrames={DURATION * FPS} fps={FPS}
      width={WIDTH} height={HEIGHT} defaultProps={{sound: true}} />
    <Composition id="DemoSilent" component={Demo} durationInFrames={DURATION * FPS} fps={FPS}
      width={WIDTH} height={HEIGHT} defaultProps={{sound: false}} />
  </>
);
