module.exports = {
  testEnvironment: 'node',
  transform: { '^.+\\.(js|ts|tsx)$': 'babel-jest' },
  moduleNameMapper: {
    '^react-native-get-random-values$': '<rootDir>/jest/rngMock.js',
  },
  // @noble/hashes 发布为 ESM，Jest 需要把它交给 Babel 转译；认证测试不需要加载 RN 原生运行时。
  transformIgnorePatterns: [
    'node_modules/(?!(@noble/hashes|react-native-get-random-values)/)',
  ],
};
