import React from 'react';
import { Platform, StyleSheet, View } from 'react-native';
import { BlurView } from '@sbaiahmed1/react-native-blur';

import { GLASS_IMPLEMENTATION } from '../../config/appConfig';
import { AndroidGlassSurface } from '../../native/AndroidGlassSurface';
import { colors, materials, radii } from '../../theme/tokens';
import {
  SkiaGlassSurface,
  type SkiaGlassSurfaceProps,
} from './SkiaGlassSurface.native';

/**
 * 玻璃材质的唯一入口（原生端）。
 * - frosted：真 backdrop blur（原生为平台模糊），保持原始高帧率光学质感。
 * - soft：半透明白 + 细描边 + 顶部高光，不开 blur，用于信息密集的字段卡。
 * - navigation：常驻悬浮导航（TabBar/Header）。Android 12+ 用 RenderEffect GPU 模糊，
 *   iOS/其他回退到 QmBlurView（视觉已验证）。
 *
 * 实现切换：GLASS_IMPLEMENTATION === 'skia' 时走 react-native-skia 渲染
 * （背景快照 + GPU 模糊 + 液态 SkSL），否则走下方旧实现；两套路径可一键回退。
 */
export function GlassSurface(props: SkiaGlassSurfaceProps) {
  if (GLASS_IMPLEMENTATION === 'skia') {
    return <SkiaGlassSurface {...props} />;
  }
  return <LegacyGlassSurface {...props} />;
}

/** 旧实现（Android AGSL/RenderEffect + iOS BlurView），保留用于回退对比。 */
function LegacyGlassSurface({
  children,
  style,
  intensity = 50,
  variant = 'frosted',
  blurRounds = 2,
  elevated = false,
  cornerRadius = radii.lg,
  liquid,
}: SkiaGlassSurfaceProps) {
  if (Platform.OS === 'android') {
    return (
      <AndroidGlassSurface
        cornerRadius={cornerRadius}
        elevated={elevated}
        liquidBlurRadius={liquid?.blurRadius}
        liquidDispersion={liquid?.dispersion}
        liquidElasticEffect={liquid?.elasticEffect}
        liquidCaptureGroup={liquid?.captureGroup}
        liquidEnabled={liquid?.enabled}
        liquidRefractionHeight={liquid?.refractionHeight}
        liquidRefractionOffset={liquid?.refractionOffset}
        liquidTouchEffect={liquid?.touchEffect}
        style={style}
        variant={variant === 'navigation' ? 'navigation' : 'soft'}
      >
        {children}
      </AndroidGlassSurface>
    );
  }

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

  if (variant === 'navigation') {
    return (
      <BlurView
        blurAmount={intensity}
        blurRounds={1}
        blurType="systemUltraThinMaterialLight"
        overlayColor={materials.chromeOverlay}
        reducedTransparencyFallbackColor={colors.surface}
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
      overlayColor={materials.frostedOverlay}
      reducedTransparencyFallbackColor={colors.surface}
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
    borderColor: materials.chromeBorder,
    borderRadius: radii.lg,
    backgroundColor: materials.frostedBase,
  },
  softSurface: {
    backgroundColor: materials.contentFill,
    borderColor: materials.contentBorder,
  },
  navigationSurface: {
    backgroundColor: materials.chromeBase,
    borderColor: materials.chromeBorder,
  },
  /** 顶部细内高光：仿 iOS 材质的高光描边，让玻璃轮廓更分明。 */
  sheen: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: StyleSheet.hairlineWidth * 3,
    backgroundColor: materials.sheen,
  },
  navigationSheen: {
    backgroundColor: materials.sheen,
  },
});
