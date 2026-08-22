import { ReduceMotion } from 'react-native-reanimated';

import { durations, springPress, springSnappy } from './config';

describe('motion tokens', () => {
  it('keeps micro-interactions short and navigation deliberate', () => {
    expect(durations.pressIn).toBeLessThan(durations.tabIndicator);
    expect(durations.headerCollapse).toBe(durations.tabIndicator);
    expect(durations.sheetIn).toBeGreaterThan(durations.pressIn);
  });

  it('respects the system reduce-motion preference', () => {
    expect(springPress.reduceMotion).toBe(ReduceMotion.System);
    expect(springSnappy.reduceMotion).toBe(ReduceMotion.System);
  });
});
