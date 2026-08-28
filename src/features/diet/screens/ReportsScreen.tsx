import React, { memo } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { FileText } from 'lucide-react-native';
import {
  AppButton,
  AppScreen,
  GlassCard,
  SectionTitle,
  Tag,
  useToast,
} from '../../../shared/components';
import { colors, fonts, spacing } from '../../../shared/theme/tokens';
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
export function ReportsScreen() {
  const { show } = useToast();
  return (
    <AppScreen>
      <StaticPageHeading
        eyebrow="健康报告"
        title="报告中心"
        description="将阶段性饮食与健康数据整理为可读结论。当前为静态预览。"
        icon={<FileText color={colors.blue} size={15} />}
      />
      <GlassCard style={styles.reportHero}>
        <View style={styles.reportIcon}>
          <FileText color={colors.inverse} size={23} />
        </View>
        <View style={styles.reportCopy}>
          <Text style={styles.reportTitle}>本周营养健康报告</Text>
          <Text style={styles.reportDescription}>2026.07.30 – 2026.08.05 · 已生成</Text>
        </View>
        <Tag label="最新" tone="green" />
      </GlassCard>
      <GlassCard>
        <SectionTitle title="本期结论" detail="根据演示数据生成" />
        <View style={styles.conclusion}>
          <View
            style={[
              styles.conclusionBullet,
              {
                backgroundColor: colors.green,
              },
            ]}
          />
          <Text style={styles.conclusionText}>饮食记录执行率 86%，较上周提高 12%。</Text>
        </View>
        <View style={styles.conclusion}>
          <View
            style={[
              styles.conclusionBullet,
              {
                backgroundColor: colors.amber,
              },
            ]}
          />
          <Text style={styles.conclusionText}>蛋白质改善明显，但晚餐钠摄入仍需要控制。</Text>
        </View>
        <View style={styles.conclusion}>
          <View
            style={[
              styles.conclusionBullet,
              {
                backgroundColor: colors.blue,
              },
            ]}
          />
          <Text style={styles.conclusionText}>建议保持清蒸、炖煮的烹饪方式并持续记录。</Text>
        </View>
        <AppButton
          label="查看演示报告"
          onPress={() => show('真实报告将在报告服务接入后生成。')}
          style={styles.marginTop}
        />
      </GlassCard>
      <SectionTitle title="历史报告" />
      <GlassCard style={styles.historyCard}>
        <HistoryRow title="7 月营养阶段报告" date="2026.07.31" score="75 分" />
        <HistoryRow title="7 月第 3 周健康摘要" date="2026.07.24" score="72 分" />
        <HistoryRow title="首次健康画像报告" date="2026.07.01" score="—" />
      </GlassCard>
    </AppScreen>
  );
}
const HistoryRow = memo(function ({
  title,
  date,
  score,
}: {
  title: string;
  date: string;
  score: string;
}) {
  return (
    <View style={styles.historyRow}>
      <View style={styles.historyDoc}>
        <FileText color={colors.blue} size={17} />
      </View>
      <View style={styles.historyText}>
        <Text style={styles.historyTitle}>{title}</Text>
        <Text style={styles.historyDate}>{date}</Text>
      </View>
      <Text style={styles.historyScore}>{score}</Text>
    </View>
  );
});
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
  marginTop: {
    marginTop: spacing.lg,
  },
  reportHero: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    backgroundColor: colors.blueSoft,
  },
  reportIcon: {
    width: 46,
    height: 46,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.blue,
  },
  reportCopy: {
    flex: 1,
  },
  reportTitle: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 16,
    fontWeight: '800',
  },
  reportDescription: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 11,
    marginTop: 4,
  },
  conclusion: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: spacing.sm,
    marginTop: spacing.md,
  },
  conclusionBullet: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginTop: 5,
  },
  conclusionText: {
    flex: 1,
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
    lineHeight: 19,
  },
  historyCard: {
    paddingVertical: 4,
  },
  historyRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    minHeight: 60,
    paddingVertical: 7,
  },
  historyDoc: {
    width: 35,
    height: 35,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.blueSoft,
  },
  historyText: {
    flex: 1,
  },
  historyTitle: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontSize: 13,
    fontWeight: '800',
  },
  historyDate: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 11,
    marginTop: 3,
  },
  historyScore: {
    color: colors.green,
    fontFamily: fonts.body,
    fontSize: 12,
    fontWeight: '800',
  },
});
