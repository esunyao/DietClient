import React from 'react';
import { View, type StyleProp, type ViewStyle } from 'react-native';

/**
 * 页面容器。
 * 转场由导航器决定；这里不再附加透明度动画，以免回退时留下白色合成层。
 */
export function ScreenTransition({ children, style }: { children: React.ReactNode; style?: StyleProp<ViewStyle> }) {
  return <View style={style}>{children}</View>;
}
