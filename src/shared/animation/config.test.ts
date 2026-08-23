import { ReduceMotion } from 'react-native-reanimated';

import { durations, motion, navigationTiming, springPress, springSnappy } from './config';

describe('motion tokens', () => {
  it('keeps micro-interactions short and navigation deliberate', () => {
    expect(motion.micro.pressIn).toBe(durations.pressIn);
    expect(motion.navigation.headerCollapse).toBe(durations.headerCollapse);
    expect(motion.data.ringSweep).toBe(durations.ringSweep);
    expect(durations.pressIn).toBeLessThan(durations.tabIndicator);
    expect(durations.headerCollapse).toBe(durations.tabIndicator);
    expect(durations.sheetIn).toBeGreaterThan(durations.pressIn);
  });

  it('uses the shared navigation easing and reduce-motion policy', () => {
    const config = navigationTiming(durations.tabIndicator);
    expect(config.duration).toBe(durations.tabIndicator);
    expect(config.reduceMotion).toBe(ReduceMotion.System);
  });

  it('respects the system reduce-motion preference', () => {
    expect(springPress.reduceMotion).toBe(ReduceMotion.System);
    expect(springSnappy.reduceMotion).toBe(ReduceMotion.System);
  });
});
