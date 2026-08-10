import React, { useEffect } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, { useAnimatedProps, useSharedValue, withTiming } from 'react-native-reanimated';
import Svg, { Circle, Defs, LinearGradient, Stop } from 'react-native-svg';

import { colors, fonts } from '../theme/tokens';
import { durations, timing } from './config';
import { useCountUp } from './useCountUp';

const AnimatedCircle = Animated.createAnimatedComponent(Circle);

/**
 * 营养评分圆环（`ScoreRing` 的动画实现，由 ui.tsx re-export）。
 * 扫入：reanimated 驱动 SVG `strokeDashoffset`（UI 线程 / Web setNativeProps）；
 * 中心数字滚动由 `useCountUp`（跨端 rAF）负责。
 */
export function AnimatedScoreRing({ score, size = 104, caption = '综合评分' }: {
  score: number;
  size?: number;
  caption?: string;
}) {
  const radius = 42;
  const circumference = 2 * Math.PI * radius;
  const progress = Math.max(0, Math.min(score, 100));
  const sweep = useSharedValue(0);

  useEffect(() => {
    sweep.value = withTiming(progress / 100, timing(durations.ringSweep));
  }, [progress, sweep]);

  const animatedProps = useAnimatedProps(() => ({
    strokeDashoffset: circumference * (1 - sweep.value),
  }));

  const display = useCountUp(score, durations.countUp);
  const containerStyle = {
    width: size,
    height: size,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  };

  return (
    <View style={containerStyle}>
      <Svg width={size} height={size} viewBox="0 0 100 100" style={styles.ringSvg}>
        <Defs>
          <LinearGradient id="nutritionOrbit" x1="0" y1="0" x2="1" y2="1">
            <Stop offset="0" stopColor={colors.blue} />
            <Stop offset="1" stopColor={colors.green} />
          </LinearGradient>
        </Defs>
        <Circle cx="50" cy="50" r={radius} stroke="#DDEAF7" strokeWidth="7" fill="none" />
        <AnimatedCircle
          cx="50"
          cy="50"
          r={radius}
          stroke="url(#nutritionOrbit)"
          strokeWidth="7"
          fill="none"
          strokeLinecap="round"
          strokeDasharray={`${circumference} ${circumference}`}
          animatedProps={animatedProps}
          transform="rotate(-90 50 50)"
        />
      </Svg>
      <View style={styles.ringCenter}>
        <Text style={styles.ringNumber}>{display}</Text>
        <Text style={styles.ringCaption}>{caption}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  ringSvg: { position: 'absolute' },
  ringCenter: { alignItems: 'center', justifyContent: 'center' },
  ringNumber: { color: colors.ink, fontFamily: fonts.display, fontSize: 27, fontWeight: '800', letterSpacing: -1 },
  ringCaption: { color: colors.muted, fontFamily: fonts.body, fontSize: 10, marginTop: -2 },
});
