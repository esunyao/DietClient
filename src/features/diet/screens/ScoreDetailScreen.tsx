import { Pressable, StyleSheet, Text, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { Activity } from 'lucide-react-native';
import type { HomeStackParamList } from '../../../navigation/types';
import { AppScreen, GlassCard, MetricProgress, ScoreRing } from '../../../shared/components';
import { colors, fonts, spacing } from '../../../shared/theme/tokens';
type ScoreProps = NativeStackScreenProps<HomeStackParamList, 'ScoreDetail'>;
export function ScoreDetailScreen({ navigation }: ScoreProps) {
  return (
    <AppScreen>
      <View style={styles.scoreDetailHeader}>
        <Pressable onPress={() => navigation.goBack()}>
          <Text style={styles.backLink}>← 返回首页</Text>
        </Pressable>
      </View>
      <View style={styles.scoreDetailTop}>
        <ScoreRing score={78} size={150} />
        <Text style={styles.scoreDetailTitle}>你的健康状态良好</Text>
        <Text style={styles.scoreDetailDescription}>
          评分由热量、营养均衡、微量营养与风险控制四个维度组成。
        </Text>
      </View>
      <GlassCard style={styles.metricList}>
        <MetricProgress label="热量适配度" value={85} color={colors.green} rightLabel="85 分" />
        <MetricProgress label="营养均衡度" value={72} color={colors.amber} rightLabel="72 分" />
        <MetricProgress
          label="微量营养素充足度"
          value={68}
          color={colors.blue}
          rightLabel="68 分"
        />
        <MetricProgress label="健康风险控制" value={90} color={colors.green} rightLabel="90 分" />
      </GlassCard>
      <GlassCard style={styles.scoreTip}>
        <Activity color={colors.blue} size={21} />
        <View style={styles.scoreTipCopy}>
          <Text style={styles.scoreTipTitle}>下一步建议</Text>
          <Text style={styles.scoreTipText}>
            晚餐增加一份优质蛋白，并避免额外酱料。评分页是静态示例，不会写入健康数据。
          </Text>
        </View>
      </GlassCard>
    </AppScreen>
  );
}

/** 识别页取景框内的扫描线：reanimated 驱动 translateY 上下往返。 */

const styles = StyleSheet.create({
  metricList: {
    gap: spacing.lg,
  },
  scoreDetailHeader: {
    minHeight: 28,
  },
  backLink: {
    color: colors.blue,
    fontFamily: fonts.body,
    fontSize: 13,
    fontWeight: '700',
  },
  scoreDetailTop: {
    alignItems: 'center',
    paddingVertical: spacing.md,
  },
  scoreDetailTitle: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 22,
    fontWeight: '800',
    marginTop: spacing.lg,
  },
  scoreDetailDescription: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
    lineHeight: 19,
    textAlign: 'center',
    marginTop: spacing.sm,
    paddingHorizontal: spacing.md,
  },
  scoreTip: {
    flexDirection: 'row',
    gap: spacing.md,
    backgroundColor: colors.blueSoft,
  },
  scoreTipCopy: {
    flex: 1,
  },
  scoreTipTitle: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontSize: 14,
    fontWeight: '800',
  },
  scoreTipText: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
    lineHeight: 19,
    marginTop: 4,
  },
});
