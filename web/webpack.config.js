/**
 * React Native Web 调试构建（webpack）
 * 依据 react-native-web 官方 multi-platform 方案配置：
 * https://necolas.github.io/react-native-web/docs/multi-platform/
 */
const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');

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
    },
  },
  module: {
    rules: [
      {
        test: /\.[jt]sx?$/,
        loader: 'babel-loader',
        options: {
          cacheDirectory: true,
          // 仅 web 构建追加 react-native-web babel 插件（根 babel.config.js 的 RN preset 仍生效）
          plugins: [require.resolve('babel-plugin-react-native-web')],
        },
        // 需转译的未编译 npm 包（负向断言排除已编译包）。
        // 注意：Windows 上路径可能是反斜杠，用 [\\/] 兼容两种分隔符，
        // 否则 webpack-dev-server 等 "type": "module" 的包被 babel 转成 CJS 后
        // 会被 webpack 仍当 ESM 解析，导致 "require is not defined"。
        exclude:
          /node_modules[\\/](?!react-native-web|react-native-safe-area-context|react-native-screens|@react-navigation)/,
      },
      {
        test: /\.(png|jpe?g|gif|svg|webp)$/i,
        type: 'asset',
      },
    ],
  },
  plugins: [
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
