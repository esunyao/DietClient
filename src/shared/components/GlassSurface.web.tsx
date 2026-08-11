import React from 'react';
import { StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';
import { BlurView } from '@sbaiahmed1/react-native-blur';

import { glass, radii } from '../theme/tokens';

/**
 * 玻璃材质的唯一入口（Web 调试端）。
 * @sbaiahmed1/react-native-blur 在 Web 用 backdrop-filter（CSS），无 RenderEffect 依赖，
 * 因此 Web 端所有变体都走它；避免引入 blur-react-native 的 codegen 组件（web 不兼容）。
 */
export function GlassSurface({
  children,
  style,
  intensity = 50,
  variant = 'frosted',
  blurRounds = 2,
}: {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  intensity?: number;
  variant?: 'frosted' | 'soft' | 'navigation';
  blurRounds?: number;
}) {
  const sheen = (
    <View
      pointerEvents="none"
      style={[styles.sheen, variant === 'navigation' && styles.navigationSheen]}
    />
  );

  if (variant === 'soft') {
    return (
      <View style={[styles.surface, styles.softSurface, style]}>
        {sheen}
        {children}
      </View>
    );
  }

  return (
    <BlurView
      blurAmount={intensity}
      // 导航浮层内容简单，单 pass 模糊视觉已够。
      blurRounds={variant === 'navigation' ? 1 : blurRounds}
      blurType="systemUltraThinMaterialLight"
      overlayColor="rgba(255, 255, 255, 0.34)"
      reducedTransparencyFallbackColor="#FFFFFF"
      style={[
        styles.surface,
        variant === 'navigation' && styles.navigationSurface,
        style,
      ]}
    >
      {sheen}
      {children}
    </BlurView>
  );
}

const styles = StyleSheet.create({
  surface: {
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: glass.borderStrong,
    borderRadius: radii.lg,
    backgroundColor: 'rgba(255, 255, 255, 0.24)',
  },
  softSurface: {
    backgroundColor: glass.tintSoft,
    borderColor: 'rgba(255, 255, 255, 0.78)',
  },
  navigationSurface: {
    backgroundColor: 'rgba(255, 255, 255, 0.66)',
    borderColor: 'rgba(148, 163, 184, 0.48)',
  },
  /** 顶部细内高光：仿 iOS 材质的高光描边，让玻璃轮廓更分明。 */
  sheen: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: StyleSheet.hairlineWidth * 3,
    backgroundColor: glass.sheen,
  },
  navigationSheen: {
    backgroundColor: 'rgba(255, 255, 255, 0.68)',
  },
});
