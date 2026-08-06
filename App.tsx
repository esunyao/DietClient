import React from 'react';
import { StatusBar } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { AppNavigator } from './src/navigation/AppNavigator';
import { ToastProvider } from './src/shared/components/Toast';
import { colors } from './src/shared/theme/tokens';

/**
 * 应用根节点只负责装配跨页面能力。
 * 路由、会话和具体业务页面分别在各自目录维护，避免入口文件演变成业务中心。
 */
function App() {
  return (
    <SafeAreaProvider>
      <StatusBar barStyle="dark-content" backgroundColor={colors.canvas} />
      <ToastProvider>
        <AppNavigator />
      </ToastProvider>
    </SafeAreaProvider>
  );
}

export default App;
