import React from 'react';
import { StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';
import { BlurView } from '@sbaiahmed1/react-native-blur';

import { glass, radii } from '../theme/tokens';

/**
 * 玻璃材质的唯一入口。
 * - `frosted`：真 backdrop blur（Web 为 backdrop-filter，原生为平台模糊），
 *   保持原始高帧率光学质感；配合顶部高光与细亮描边让玻璃轮廓更分明。
 * - `soft`：半透明白 + 细描边 + 顶部高光，**不开 blur**，仅用于信息密集的字段卡，
 *   保留玻璃观感的同时减少模糊层叠加。
 * - `navigation`：稳定的浅色玻璃底 + 蓝灰描边，供悬浮导航使用，
 *   即使页面背景很浅也能保持明确边界。
 */
export function GlassSurface({
  children,
  style,
  intensity = 50,
  variant = 'frosted',
}: {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  intensity?: number;
  variant?: 'frosted' | 'soft' | 'navigation';
}) {
  const sheen = <View pointerEvents="none" style={[styles.sheen, variant === 'navigation' && styles.navigationSheen]} />;

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
      blurRounds={6}
      blurType="systemUltraThinMaterialLight"
      overlayColor="rgba(255, 255, 255, 0.30)"
      reducedTransparencyFallbackColor="#FFFFFF"
      style={[styles.surface, variant === 'navigation' && styles.navigationSurface, style]}
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
  },
  navigationSurface: {
    backgroundColor: 'rgba(255, 255, 255, 0.82)',
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
    backgroundColor: 'rgba(255, 255, 255, 0.92)',
  },
});
