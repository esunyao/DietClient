const React = require('react');
const { View } = require('react-native');

/** SkiaGlassSurface 原生容器 mock：普通 View，透传全部 props（含 onSnapshot 回调）。 */
module.exports = React.forwardRef(function MockSkiaGlassSurface(props, ref) {
  const { children, ...rest } = props;
  return React.createElement(View, { ref, ...rest }, children);
});
