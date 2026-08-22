import React, { useEffect } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, { useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';

import { colors, fonts, radii, spacing } from '../theme/tokens';
import { durations, timing } from './config';

/**
 * 进度条指标（`MetricProgress` 的动画实现，由 ui.tsx re-export）。
 * 填充用 `scaleX` + `transformOrigin: 'left center'` 从左生长，只动 transform，
 * 避免改 width 触发布局抖动；track `overflow: hidden` 收边。
 */
export function AnimatedProgress({
  label,
  value,
  color = colors.blue,
  rightLabel,
}: {
  label: string;
  value: number;
  color?: string;
  rightLabel?: string;
}) {
  const safeValue = Math.max(0, Math.min(value, 100));
  const progress = useSharedValue(0);

  useEffect(() => {
    progress.value = withTiming(safeValue / 100, timing(durations.barGrow));
  }, [safeValue, progress]);

  const fillStyle = useAnimatedStyle(() => ({
    transformOrigin: 'left center',
    transform: [{ scaleX: progress.value }],
  }));

  return (
    <View style={styles.metric}>
      <View style={styles.metricHead}>
        <Text style={styles.metricLabel}>{label}</Text>
        <Text style={styles.metricValue}>{rightLabel || `${safeValue}%`}</Text>
      </View>
      <View style={styles.progressTrack}>
        <Animated.View style={[styles.progressFill, { backgroundColor: color }, fillStyle]} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  metric: { gap: 6 },
  metricHead: { flexDirection: 'row', justifyContent: 'space-between', gap: spacing.md },
  metricLabel: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '600' },
  metricValue: { color: colors.muted, fontFamily: fonts.mono, fontSize: 12, fontWeight: '700' },
  progressTrack: { height: 6, borderRadius: radii.pill, backgroundColor: colors.surfaceMuted, overflow: 'hidden' },
  // 默认沿 track 拉伸为全宽，scaleX 决定可见占比。
  progressFill: { height: '100%', borderRadius: radii.pill },
});
