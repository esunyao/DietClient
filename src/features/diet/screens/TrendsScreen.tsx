import React, { memo, useEffect, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Heart, TrendingUp } from 'lucide-react-native';
import Animated, { useAnimatedStyle, useSharedValue, withSpring } from 'react-native-reanimated';
import { springGentle } from '../../../shared/animation/config';
import {
  AppScreen,
  GlassCard,
  MetricProgress,
  SectionTitle,
  Tag,
} from '../../../shared/components';
import { colors, fonts, radii, spacing } from '../../../shared/theme/tokens';
const StaticPageHeading = memo(function ({
  eyebrow,
  title,
  description,
  icon,
}: {
  eyebrow: string;
  title: string;
  description: string;
  icon: React.ReactNode;
}) {
  return (
    <View style={styles.pageHeading}>
      <View style={styles.eyebrowRow}>
        <View style={styles.eyebrowIcon}>{icon}</View>
        <Text style={styles.eyebrow}>{eyebrow}</Text>
      </View>
      <Text style={styles.pageTitle}>{title}</Text>
      <Text style={styles.pageDescription}>{description}</Text>
    </View>
  );
});
export function TrendsScreen() {
  const [range, setRange] = useState('周');
  const values =
    range === '周'
      ? [72, 75, 73, 77, 76, 80, 78]
      : range === '月'
      ? [68, 72, 74, 76, 78, 79]
      : [62, 69, 73, 78];
  return (
    <AppScreen>
      <StaticPageHeading
        eyebrow="数据统计"
        title="健康趋势"
        description="模拟展示饮食执行与身体状态的阶段性变化。"
        icon={<TrendingUp color={colors.blue} size={15} />}
      />
      <View style={styles.rangeSwitch}>
        {['周', '月', '季'].map(item => (
          <Pressable
            key={item}
            onPress={() => setRange(item)}
            style={[styles.rangeItem, range === item && styles.rangeItemActive]}
          >
            <Text style={[styles.rangeText, range === item && styles.rangeTextActive]}>{item}</Text>
          </Pressable>
        ))}
      </View>
      <GlassCard>
        <View style={styles.chartHead}>
          <View>
            <Text style={styles.chartTitle}>综合健康评分</Text>
            <Text style={styles.chartDescription}>当前 78 · 较周期开始 +6</Text>
          </View>
          <Tag label="稳步改善" tone="green" />
        </View>
        <View style={styles.chart}>
          {values.map((value, index) => (
            <View key={`${value}-${index}`} style={styles.barColumn}>
              <Text style={styles.barValue}>{value}</Text>
              <GrowingBar
                value={value}
                color={index === values.length - 1 ? colors.green : colors.blue}
              />
              <Text style={styles.barLabel}>{index + 1}</Text>
            </View>
          ))}
        </View>
      </GlassCard>
      <SectionTitle title="本周期执行反馈" />
      <GlassCard style={styles.metricList}>
        <MetricProgress label="饮食记录完成率" value={86} color={colors.green} rightLabel="86%" />
        <MetricProgress label="营养目标达标率" value={74} color={colors.blue} rightLabel="74%" />
        <MetricProgress label="餐食满意度" value={89} color={colors.green} rightLabel="4.5 / 5" />
      </GlassCard>
      <GlassCard style={styles.trendInsight}>
        <Heart color={colors.red} size={20} />
        <View style={styles.trendInsightCopy}>
          <Text style={styles.trendInsightTitle}>本周健康提示</Text>
          <Text style={styles.trendInsightText}>
            蛋白质摄入持续改善；周末仍建议留意外卖和调味料中的隐性钠。
          </Text>
        </View>
      </GlassCard>
    </AppScreen>
  );
}
/** 趋势图柱：scaleY 从底部生长（transform 驱动，不动 height）。 */
function GrowingBar({ value, color }: { value: number; color: string }) {
  const scale = useSharedValue(0);
  useEffect(() => {
    scale.value = withSpring(1, springGentle);
  }, [scale]);
  const style = useAnimatedStyle(() => ({
    transformOrigin: 'bottom center',
    transform: [
      {
        scaleY: scale.value,
      },
    ],
  }));
  return (
    <Animated.View
      style={[
        styles.bar,
        {
          height: `${value}%`,
          backgroundColor: color,
        },
        style,
      ]}
    />
  );
}
const styles = StyleSheet.create({
  pageHeading: {
    gap: 6,
  },
  eyebrowRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  eyebrowIcon: {
    width: 24,
    height: 24,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.blueSoft,
  },
  eyebrow: {
    color: colors.blue,
    fontFamily: fonts.body,
    fontSize: 12,
    fontWeight: '800',
  },
  pageTitle: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 28,
    fontWeight: '800',
    letterSpacing: -0.8,
  },
  pageDescription: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 13,
    lineHeight: 20,
  },
  metricList: {
    gap: spacing.lg,
  },
  rangeSwitch: {
    flexDirection: 'row',
    alignSelf: 'flex-start',
    backgroundColor: colors.surfaceMuted,
    borderRadius: radii.pill,
    padding: 3,
  },
  rangeItem: {
    minWidth: 52,
    alignItems: 'center',
    borderRadius: radii.pill,
    paddingVertical: 7,
    paddingHorizontal: spacing.sm,
  },
  rangeItemActive: {
    backgroundColor: colors.surface,
  },
  rangeText: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
    fontWeight: '700',
  },
  rangeTextActive: {
    color: colors.blue,
  },
  chartHead: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: spacing.sm,
  },
  chartTitle: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 17,
    fontWeight: '800',
  },
  chartDescription: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 11,
    marginTop: 4,
  },
  chart: {
    height: 178,
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'space-around',
    gap: 5,
    marginTop: spacing.xl,
    borderBottomWidth: 1,
    borderColor: colors.line,
  },
  barColumn: {
    flex: 1,
    height: '100%',
    justifyContent: 'flex-end',
    alignItems: 'center',
    gap: 4,
  },
  bar: {
    width: '66%',
    minHeight: 10,
    borderTopLeftRadius: 8,
    borderTopRightRadius: 8,
    opacity: 0.92,
  },
  barValue: {
    color: colors.muted,
    fontFamily: fonts.mono,
    fontSize: 10,
  },
  barLabel: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 10,
    paddingBottom: 4,
  },
  trendInsight: {
    flexDirection: 'row',
    gap: spacing.md,
    backgroundColor: colors.redSoft,
  },
  trendInsightCopy: {
    flex: 1,
  },
  trendInsightTitle: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontWeight: '800',
    fontSize: 14,
  },
  trendInsightText: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
    lineHeight: 19,
    marginTop: 4,
  },
});
