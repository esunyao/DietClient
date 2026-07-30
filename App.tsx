/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import { NewAppScreen } from '@react-native/new-app-screen';
import { StatusBar, StyleSheet, useColorScheme, View } from 'react-native';
import {
  SafeAreaProvider,
  useSafeAreaInsets,
} from 'react-native-safe-area-context';

import { HomeScreen } from './src/features/diet/screens/HomeScreen';

/**
 * -----------------------------------------------------------------------------
 * 🎓 React Native 根入口组件 (App.tsx)
 * -----------------------------------------------------------------------------
 * 职责：
 * 1. 挂载全局上下文 Provider（例如 Safe Area 适配、路由容器 NavigationContainer、全局状态管理等）
 * 2. 作为全局 UI 的顶层入口
 * -----------------------------------------------------------------------------
 */
function App() {
  return (
    <SafeAreaProvider>
      {/* 直接渲染我们刚编写的 HomeScreen 样板 */}
      <HomeScreen />
    </SafeAreaProvider>
  );
}

export default App;
