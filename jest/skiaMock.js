const React = require('react');
const { View } = require('react-native');

/** 轻量结构 mock：Canvas/Group 保留子节点结构，绘制原语渲染为 null。 */
const drawable = () => null;

function passthrough({ children }) {
  return React.createElement(View, null, children);
}

module.exports = {
  Canvas: passthrough,
  Group: passthrough,
  Fill: drawable,
  Rect: drawable,
  RRect: drawable,
  RoundedRect: drawable,
  Circle: drawable,
  Image: ({ children }) => (children ? React.createElement(View, null, children) : null),
  ImageShader: drawable,
  Shader: ({ children }) => (children ? React.createElement(View, null, children) : null),
  Blur: ({ children }) => (children ? React.createElement(View, null, children) : null),
  LinearGradient: drawable,
  vec: (...args) => args,
  Skia: {
    Data: {
      fromBase64: value => ({ __skData: value }),
    },
    Image: {
      MakeImageFromEncoded: data => (data ? { __skImage: data } : null),
    },
    RuntimeEffect: {
      Make: () => ({ __skRuntimeEffect: true }),
    },
  },
};
