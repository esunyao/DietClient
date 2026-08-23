import { resolveGlassImplementation } from './glassImplementation';

describe('resolveGlassImplementation', () => {
  it('iOS navigation and frosted materials use the native live material', () => {
    expect(resolveGlassImplementation('ios', 'navigation')).toBe('native');
    expect(resolveGlassImplementation('ios', 'frosted')).toBe('native');
  });

  it('iOS soft material stays a static surface', () => {
    expect(resolveGlassImplementation('ios', 'soft')).toBe('skia');
  });

  it('Android keeps the Skia implementation by default', () => {
    expect(resolveGlassImplementation('android', 'navigation')).toBe('skia');
    expect(resolveGlassImplementation('android', 'frosted')).toBe('skia');
  });

  it('the explicit native configuration remains an escape hatch', () => {
    expect(resolveGlassImplementation('android', 'navigation', 'native')).toBe('native');
  });
});
