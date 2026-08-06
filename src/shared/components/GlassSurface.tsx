import React from 'react';
import { StyleSheet, type StyleProp, type ViewStyle } from 'react-native';
import { BlurView } from '@sbaiahmed1/react-native-blur';

import { colors, radii } from '../theme/tokens';

/**
 * 玻璃材质的唯一入口。
 * BlurView 在 Web 使用 backdrop-filter，在原生端使用各平台的模糊实现；
 * 这样页面不需要各自维护一套半透明背景和兼容性降级逻辑。
 */
export function GlassSurface({
  children,
  style,
  intensity = 36,
}: {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  intensity?: number;
}) {
  return (
    <BlurView
      blurAmount={intensity}
      blurRounds={4}
      blurType="systemUltraThinMaterialLight"
      overlayColor="rgba(255, 255, 255, 0.58)"
      reducedTransparencyFallbackColor={colors.surface}
      style={[styles.surface, style]}
    >
      {children}
    </BlurView>
  );
}

const styles = StyleSheet.create({
  surface: {
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.88)',
    borderRadius: radii.lg,
    backgroundColor: 'rgba(255, 255, 255, 0.56)',
  },
});
