const { View } = require('react-native');

/**
 * react-native-reanimated 的最小 Jest mock。
 * 不依赖官方 mock（其 src 链会拉入未转译的 react-native-worklets ESM）。
 * 仅需支持 SkiaGlassSurface 用到的 API 面。
 */

function makeMutable(initial) {
  return { value: initial };
}

module.exports = {
  useSharedValue: initial => makeMutable(initial),
  useDerivedValue: fn => ({ value: fn() }),
  useAnimatedStyle: fn => fn(),
  useAnimatedProps: fn => fn(),
  withTiming: value => value,
  withSpring: value => value,
  Easing: {
    inOut: fn => fn,
    out: fn => fn,
    quad: value => value,
    cubic: value => value,
  },
  ReduceMotion: { System: 'system' },
  runOnJS: fn => fn,
  interpolate: (value, _input, _output) => value,
  makeMutable,
  Animated: { View },
};
