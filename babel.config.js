module.exports = {
  presets: ['module:@react-native/babel-preset'],
  // Reanimated 的 worklet 编译必须在 Babel 链末尾执行，供底部抽屉和过渡动画使用。
  plugins: ['react-native-worklets/plugin'],
};
