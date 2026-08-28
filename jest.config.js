module.exports = {
  preset: 'react-native',
  testEnvironment: 'node',
  setupFiles: ['<rootDir>/jest/setup.js'],
  transform: { '^.+[.](js|ts|tsx)$': 'babel-jest' },
  collectCoverageFrom: [
    'src/**/*.{ts,tsx}',
    '!src/**/*.test.{ts,tsx}',
    '!src/**/index.ts',
    '!src/**/*Types.ts',
    '!src/**/*.types.ts',
    '!src/shared/config/**',
    '!src/shared/native/*NativeComponent.ts',
  ],
  moduleNameMapper: {
    '^react-native-get-random-values$': '<rootDir>/jest/rngMock.js',
    '^@shopify/react-native-skia$': '<rootDir>/jest/skiaMock.js',
    '^(?:.*/)SkiaGlassSurfaceNativeComponent$': '<rootDir>/jest/skiaGlassNativeMock.js',
    '^react-native-reanimated$': '<rootDir>/jest/reanimatedMock.js',
  },
  // RN preset 的默认规则：转译 react-native 与 @react-native 系列（ESM 产物），
  // 并补充 @noble/hashes（ESM）与 reanimated mock。
  transformIgnorePatterns: [
    'node_modules/(?!((jest-)?react-native|@react-native(-community)?|@noble/hashes|react-native-get-random-values|react-native-reanimated)/)',
  ],
};
