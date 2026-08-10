import React, { useEffect } from 'react';
import { Platform, type StyleProp, type ViewStyle } from 'react-native';
import Animated, { useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';

import { durations, timing } from './config';

/**
 * 页面进入淡入（仅 Web，纯 opacity，挂载时播放一次）。
 * react-native-screens 的 Web 实现是纯 View（native-stack 动画在 Web 不生效），
 * 因此由本组件在页面首次挂载时播放一次淡入；tab 切回等再次聚焦时**不重放**，
 * 避免旧页淡出 + 新页淡入叠加造成"闪一下"。
 * 原生端恒 opacity 1，完全交给 native-stack 原生动画。
 */
export function ScreenTransition({ children, style }: { children: React.ReactNode; style?: StyleProp<ViewStyle> }) {
  const web = Platform.OS === 'web';
  const progress = useSharedValue(web ? 0 : 1);

  useEffect(() => {
    if (!web) return;
    progress.value = withTiming(1, timing(durations.screenTransition));
  }, [progress, web]);

  const animatedStyle = useAnimatedStyle(() => ({
    opacity: web ? progress.value : 1,
  }));

  return <Animated.View style={[style, animatedStyle]}>{children}</Animated.View>;
}
