/**
 * Web 专用入口（react-native-web + webpack）
 * 原生端仍使用 index.js（Metro 仅在 platform=web 时解析本文件）
 *
 * @format
 */

import { AppRegistry } from 'react-native';
import App from './App';
import { name as appName } from './app.json';

AppRegistry.registerComponent(appName, () => App);

// webpack-dev-server HMR 热更新
if (module.hot) {
  module.hot.accept();
}

AppRegistry.runApplication(appName, {
  initialProps: {},
  rootTag: document.getElementById('root'),
});
