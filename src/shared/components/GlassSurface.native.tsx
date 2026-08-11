import React from 'react';
import { Platform, StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';
import { BlurView } from '@sbaiahmed1/react-native-blur';
// Android 12+ 用 RenderEffect GPU 硬件加速模糊（替代 QmBlurView 的 CPU box-blur），
// API <31 由该库内部回退；仅用于常驻的导航浮层（TabBar/Header）。
import { BlurView as RenderBlurView } from 'blur-react-native';

import { glass, radii } from '../theme/tokens';

/**
 * 玻璃材质的唯一入口（原生端）。
 * - `frosted`：真 backdrop blur（原生为平台模糊），保持原始高帧率光学质感。
 * - `soft`：半透明白 + 细描边 + 顶部高光，**不开 blur**，用于信息密集的字段卡。
 * - `navigation`：常驻悬浮导航（TabBar/Header）。Android 12+ 用 RenderEffect GPU 模糊，
 *   iOS/其他回退到 QmBlurView（视觉已验证）。
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
  /** QmBlurView 专属：每帧模糊 pass 数，越低越省 CPU，默认 2。 */
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

  // 常驻导航浮层（TabBar/Header）：Android 12+ 用 RenderEffect GPU 模糊。
  if (variant === 'navigation') {
    if (Platform.OS === 'android') {
      return (
        <RenderBlurView
          blurType="systemUltraThinMaterial"
          blurAmount={intensity}
          reducedTransparencyFallbackColor="#FFFFFF"
          style={StyleSheet.flatten([styles.surface, styles.navigationSurface, style])}
        >
          {/* blur-react-native 无 overlayColor prop，用白色半透明层补偿原视觉。 */}
          <View pointerEvents="none" style={styles.navigationOverlay} />
          {sheen}
          {children}
        </RenderBlurView>
      );
    }
    return (
      <BlurView
        blurAmount={intensity}
        blurRounds={1}
        blurType="systemUltraThinMaterialLight"
        overlayColor="rgba(255, 255, 255, 0.34)"
        reducedTransparencyFallbackColor="#FFFFFF"
        style={[styles.surface, styles.navigationSurface, style]}
      >
        {sheen}
        {children}
      </BlurView>
    );
  }

  return (
    <BlurView
      blurAmount={intensity}
      blurRounds={blurRounds}
      blurType="systemUltraThinMaterialLight"
      overlayColor="rgba(255, 255, 255, 0.34)"
      reducedTransparencyFallbackColor="#FFFFFF"
      style={[styles.surface, style]}
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
  /** 模拟原 QmBlurView 的 overlayColor 白色覆盖，让低强度模糊不显得太透。 */
  navigationOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(255, 255, 255, 0.34)',
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
