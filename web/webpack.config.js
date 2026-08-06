/**
 * React Native Web 调试构建（webpack）
 * 依据 react-native-web 官方 multi-platform 方案配置：
 * https://necolas.github.io/react-native-web/docs/multi-platform/
 */
const path = require('path');
const webpack = require('webpack');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');
const NodePolyfillPlugin = require('node-polyfill-webpack-plugin');

const appDirectory = path.resolve(__dirname, '..');
const isProduction = process.env.NODE_ENV === 'production';

module.exports = {
  mode: isProduction ? 'production' : 'development',
  entry: path.resolve(appDirectory, 'index.web.js'),
  devtool: isProduction ? 'source-map' : 'cheap-module-source-map',
  output: {
    path: path.resolve(appDirectory, 'dist/web'),
    filename: 'bundle.js',
    publicPath: '/',
    clean: true,
  },
  resolve: {
    // web 专属扩展名优先（react-native-safe-area-context 的 .web.tsx 依赖此解析）
    extensions: [
      '.web.js',
      '.web.ts',
      '.web.tsx',
      '.js',
      '.jsx',
      '.ts',
      '.tsx',
      '.json',
    ],
    alias: {
      // 把 react-native 精确替换为 react-native-web
      'react-native$': 'react-native-web',
      // AsyncStorage 的 package exports 同时暴露 TS source；webpack + Babel 会把它转成
      // 浏览器不能直接执行的 CommonJS exports。Web 端固定使用已编译的模块入口。
      '@react-native-async-storage/async-storage$': path.resolve(
        appDirectory,
        'node_modules/@react-native-async-storage/async-storage/lib/module/index.js',
      ),
      // Skia 的 Web 图形模块会用到 Node 兼容项；交由 polyfill 插件提供浏览器实现。
      'react-native-reanimated/package.json$': path.resolve(appDirectory, 'node_modules/react-native-reanimated/package.json'),
    },
  },
  module: {
    rules: [
      {
        // AsyncStorage 的 Web ESM 产物仍有省略 .js 的内部导入。
        // Webpack 5 对严格 ESM 默认要求完整扩展名，关闭该限制以兼容 RN 生态包。
        test: /\.m?js$/,
        resolve: { fullySpecified: false },
      },
      {
        test: /\.[jt]sx?$/,
        loader: 'babel-loader',
        options: {
          cacheDirectory: true,
          // 仅 web 构建追加 react-native-web babel 插件（根 babel.config.js 的 RN preset 仍生效）
          plugins: [require.resolve('babel-plugin-react-native-web')],
        },
        // 仅转译 React Native Web 运行时；React Navigation 已发布 ESM 产物，
        // 若再经 RN Babel preset 转为 CJS，会在浏览器触发 `exports is not defined`。
        // Windows 路径可能为反斜杠，因此用 [\\/] 同时兼容两种分隔符。
        exclude:
          /node_modules[\\/](?!react-native-web|react-native-safe-area-context|react-native-screens|react-native-image-picker)/,
      },
      {
        test: /\.(png|jpe?g|gif|svg|webp)$/i,
        type: 'asset',
      },
    ],
  },
  plugins: [
    // React Native 生态包会在运行时读取此编译期常量；Webpack 默认不会像 Metro 一样注入它。
    new webpack.DefinePlugin({ __DEV__: JSON.stringify(!isProduction) }),
    new NodePolyfillPlugin(),
    // WithSkiaWeb 延迟加载 CanvasKit；WASM 单独复制后可被 locateFile('/canvaskit.wasm') 找到。
    new CopyWebpackPlugin({
      patterns: [
        {
          from: require.resolve('canvaskit-wasm/bin/full/canvaskit.wasm'),
          to: 'canvaskit.wasm',
        },
      ],
    }),
    // NODE_ENV 由 webpack 的 mode 自动注入，无需手动 DefinePlugin
    new HtmlWebpackPlugin({
      template: path.resolve(__dirname, 'index.html'),
    }),
  ],
  devServer: {
    port: 8080,
    host: '0.0.0.0',
    hot: true,
    open: true,
    historyApiFallback: true, // 为将来接入路由做准备
    static: { directory: path.resolve(appDirectory, 'web') },
  },
  performance: { hints: false },
};
