import React from 'react';
import { StyleSheet } from 'react-native';
import { Canvas, Circle, Fill, RadialGradient, vec } from '@shopify/react-native-skia';

type Props = { width: number; height: number; activeIndex: number };

/**
 * Skia 只绘制底栏的色散光晕，交互仍由 React Native Pressable 处理。
 * 这保留了高帧率的光学质感，也不会为普通页面卡片引入 Canvas 重绘成本。
 */
export default function SkiaTabBarChrome({ width, height, activeIndex }: Props) {
  if (!width || !height) {
    return null;
  }

  const tabWidth = width / 6;
  const activeX = tabWidth * (activeIndex + 0.5);

  return (
    <Canvas style={StyleSheet.flatten([StyleSheet.absoluteFill, { pointerEvents: 'none' }])}>
      <Fill color="rgba(245, 250, 255, 0.22)" />
      <Circle cx={activeX} cy={height * 0.18} r={tabWidth * 0.88}>
        <RadialGradient
          c={vec(activeX, height * 0.18)}
          colors={['rgba(0,113,227,0.22)', 'rgba(52,199,89,0.07)', 'rgba(255,255,255,0)']}
          r={tabWidth * 0.88}
        />
      </Circle>
      <Circle cx={width * 0.08} cy={height * 0.06} r={width * 0.32}>
        <RadialGradient c={vec(width * 0.08, height * 0.06)} colors={['rgba(255,255,255,0.72)', 'rgba(255,255,255,0)']} r={width * 0.32} />
      </Circle>
      <Circle cx={width * 0.88} cy={height * 0.96} r={width * 0.3}>
        <RadialGradient c={vec(width * 0.88, height * 0.96)} colors={['rgba(109,93,251,0.09)', 'rgba(255,255,255,0)']} r={width * 0.3} />
      </Circle>
    </Canvas>
  );
}
