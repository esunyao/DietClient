import React, { memo, useCallback, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { useFocusEffect } from '@react-navigation/native';
import {
  ArrowRight,
  Camera,
  CircleAlert,
  Sparkles,
  Target,
  TrendingUp,
  Utensils,
} from 'lucide-react-native';
import type { HomeStackParamList } from '../../../navigation/types';
import { AppScreen, GlassCard, ScoreRing, SectionTitle, Tag } from '../../../shared/components';
import { colors, fonts, radii, spacing } from '../../../shared/theme/tokens';
import { nutriApi } from '../api/nutriApi';
import type { MealHistoryItem, NutrientValue } from '../api/nutriTypes';
import { localDateFromDate } from '../services/mealCapture';
type HomeProps = NativeStackScreenProps<HomeStackParamList, 'HomeMain'>;
const MiniNutrition = memo(function ({
  label,
  value,
  unit,
}: {
  label: string;
  value: string;
  unit: string;
}) {
  const fillStyle =
    label === '蛋白质'
      ? styles.microFillProtein
      : label === '碳水'
      ? styles.microFillCarbs
      : label === '脂肪'
      ? styles.microFillFat
      : styles.microFillCalories;
  return (
    <GlassCard style={styles.nutritionCard}>
      <Text style={styles.nutritionLabel}>{label}</Text>
      <Text style={styles.nutritionValue}>
        {value}
        <Text style={styles.nutritionUnit}> {unit}</Text>
      </Text>
      <View style={styles.microTrack}>
        <View style={[styles.microFill, fillStyle]} />
      </View>
    </GlassCard>
  );
});
const RecordRow = memo(function ({
  emoji,
  name,
  detail,
  tag,
  tone = 'green',
  onPress,
}: {
  emoji: string;
  name: string;
  detail: string;
  tag: string;
  tone?: 'green' | 'amber';
  onPress?: () => void;
}) {
  return (
    <Pressable
      accessibilityRole={onPress ? 'button' : undefined}
      onPress={onPress}
      style={styles.recordRow}
    >
      <View style={styles.recordEmoji}>
        <Text>{emoji}</Text>
      </View>
      <View style={styles.recordInfo}>
        <Text style={styles.recordName}>{name}</Text>
        <Text style={styles.recordDetail}>{detail}</Text>
      </View>
      <Tag label={tag} tone={tone} />
    </Pressable>
  );
});
function nutrientValue(nutrients: NutrientValue[], code: string): number {
  return nutrients.find(item => item.nutrientCode === code)?.amount ?? 0;
}
function formatNutrient(value: number): string {
  return Number.isInteger(value) ? String(value) : value.toFixed(1).replace(/\.0$/, '');
}
function recordEmoji(meal: MealHistoryItem): string {
  return {
    breakfast: '🥣',
    lunch: '🥗',
    dinner: '🍲',
    snack: '🍎',
    other: '🍽️',
  }[meal.mealType];
}
export function HomeScreen({ navigation }: HomeProps) {
  const [todayMeals, setTodayMeals] = useState<MealHistoryItem[]>([]);
  const [todayNutrients, setTodayNutrients] = useState<NutrientValue[]>([]);
  const [loadingMeals, setLoadingMeals] = useState(true);
  const today = localDateFromDate();
  const openDiet = useCallback(
    (
      screen?: 'Recognition' | 'MealHistory' | 'MealDetail',
      params?: {
        mealId: string;
      },
    ) => {
      const tabNavigation = navigation.getParent() as unknown as
        | {
            navigate: (name: string, params?: unknown) => void;
          }
        | undefined;
      if (!screen || screen === 'Recognition') {
        tabNavigation?.navigate('RecognitionTab');
        return;
      }
      tabNavigation?.navigate('RecognitionTab', {
        screen,
        params,
      });
    },
    [navigation],
  );
  const loadToday = useCallback(async () => {
    setLoadingMeals(true);
    try {
      const [summary, mealPage] = await Promise.all([
        nutriApi.getDailySummary(today),
        nutriApi.listMeals({
          dateFrom: today,
          dateTo: today,
          pageSize: 20,
        }),
      ]);
      setTodayNutrients(summary.nutrients);
      setTodayMeals(mealPage.items);
    } catch {
      // 首页不弹出网络错误，空态保留可继续记录的主操作。
      setTodayNutrients([]);
      setTodayMeals([]);
    } finally {
      setLoadingMeals(false);
    }
  }, [today]);
  useFocusEffect(
    useCallback(() => {
      loadToday();
    }, [loadToday]),
  );
  return (
    <AppScreen>
      <View style={styles.homeHeader}>
        <View>
          <Text style={styles.greetingSmall}>2026 年 8 月 5 日 · 下午好</Text>
          <Text style={styles.greetingTitle}>今天吃得怎么样？</Text>
        </View>
        <View style={styles.smallBrand}>
          <Utensils color={colors.blue} size={19} />
        </View>
      </View>

      <GlassCard style={styles.scoreCard}>
        <View style={styles.scoreHalo} />
        <ScoreRing score={78} />
        <View style={styles.scoreCopy}>
          <View style={styles.scoreTitleRow}>
            <Text style={styles.scoreTitle}>状态良好</Text>
            <Tag label="今日达标" tone="green" />
          </View>
          <Text style={styles.scoreDescription}>
            热量适中，蛋白质偏低。晚餐适合补充豆腐、鱼类或鸡胸肉。
          </Text>
          <Pressable onPress={() => navigation.navigate('ScoreDetail')} style={styles.detailLink}>
            <Text style={styles.detailLinkText}>查看健康评分</Text>
            <ArrowRight color={colors.blue} size={14} />
          </Pressable>
        </View>
      </GlassCard>

      <View style={styles.warning}>
        <CircleAlert color={colors.amberInk} size={18} />
        <View style={styles.warningCopy}>
          <Text style={styles.warningTitle}>钠摄入预警</Text>
          <Text style={styles.warningText}>已达目标 82%，晚餐请注意控盐。</Text>
        </View>
        <Tag label="建议" tone="amber" />
      </View>

      <View style={styles.quickGrid}>
        <QuickAction
          icon={<Camera color={colors.blue} size={22} />}
          title="识别这一餐"
          description="拍照 · AI 分析"
          blue
          onPress={() => openDiet()}
        />
        <QuickAction
          icon={<Sparkles color={colors.green} size={22} />}
          title="下一餐处方"
          description="AI 配餐"
        />
        <QuickAction
          icon={<Target color={colors.blue} size={22} />}
          title="今日目标"
          description="调整目标"
        />
        <QuickAction
          icon={<TrendingUp color={colors.blue} size={22} />}
          title="历史追踪"
          description="饮食 & 身体"
        />
      </View>

      <SectionTitle
        title="今日营养摄入"
        detail={
          loadingMeals
            ? '正在加载…'
            : todayMeals.length
            ? `${todayMeals.length} 餐已记录`
            : '还没有餐食记录'
        }
      />
      <View style={styles.nutritionGrid}>
        <MiniNutrition
          label="热量"
          value={formatNutrient(nutrientValue(todayNutrients, 'ENERGY_KCAL'))}
          unit="kcal"
        />
        <MiniNutrition
          label="蛋白质"
          value={formatNutrient(nutrientValue(todayNutrients, 'PROTEIN'))}
          unit="g"
        />
        <MiniNutrition
          label="碳水"
          value={formatNutrient(nutrientValue(todayNutrients, 'CARBOHYDRATE'))}
          unit="g"
        />
        <MiniNutrition
          label="脂肪"
          value={formatNutrient(nutrientValue(todayNutrients, 'FAT'))}
          unit="g"
        />
      </View>

      <SectionTitle
        title="今日饮食记录"
        action={
          <Pressable onPress={() => openDiet('MealHistory')}>
            <Text style={styles.actionText}>全部记录</Text>
          </Pressable>
        }
      />
      <GlassCard style={styles.records}>
        {todayMeals.map(meal => (
          <RecordRow
            key={meal.mealId}
            emoji={recordEmoji(meal)}
            name={meal.notes || '已分析餐食'}
            detail={`${
              meal.mealType === 'breakfast'
                ? '早餐'
                : meal.mealType === 'lunch'
                ? '午餐'
                : meal.mealType === 'dinner'
                ? '晚餐'
                : meal.mealType === 'snack'
                ? '加餐'
                : '其他'
            } · ${new Date(meal.consumedAt).toLocaleTimeString([], {
              hour: '2-digit',
              minute: '2-digit',
            })} · ${formatNutrient(nutrientValue(meal.nutrients, 'ENERGY_KCAL'))} kcal`}
            tag="已分析"
            tone="green"
            onPress={() =>
              openDiet('MealDetail', {
                mealId: meal.mealId,
              })
            }
          />
        ))}
        {!loadingMeals && !todayMeals.length ? (
          <Pressable onPress={() => openDiet()} style={styles.emptyRecords}>
            <Text style={styles.emptyRecordsText}>今天还没有餐食记录，点击开始记录。</Text>
          </Pressable>
        ) : null}
      </GlassCard>

      <GlassCard style={styles.prescription}>
        <View style={styles.prescriptionHead}>
          <Sparkles color={colors.blue} size={19} />
          <Text style={styles.prescriptionTitle}>AI 下一餐处方</Text>
          <Tag label="晚餐推荐" tone="green" />
        </View>
        <Text style={styles.prescriptionDescription}>
          基于演示健康画像与今日累计营养，推荐低钠、高蛋白的一餐。
        </Text>
        <View style={styles.prescriptionGrid}>
          <PrescriptionMetric label="推荐热量" value="450 kcal" />
          <PrescriptionMetric label="蛋白质" value="≥ 35g" />
          <PrescriptionMetric label="推荐食材" value="豆腐 · 西兰花" />
          <PrescriptionMetric label="注意事项" value="控钠 · 高纤维" />
        </View>
      </GlassCard>
    </AppScreen>
  );
}
const QuickAction = memo(function ({
  icon,
  title,
  description,
  blue = false,
  onPress,
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
  blue?: boolean;
  onPress?: () => void;
}) {
  return (
    <Pressable
      accessibilityRole={onPress ? 'button' : undefined}
      onPress={onPress}
      style={styles.quickAction}
    >
      <GlassCard style={[styles.quickActionCard, blue && styles.quickActionBlue]}>
        <View style={[styles.quickIcon, blue && styles.quickIconBlue]}>{icon}</View>
        <Text style={[styles.quickTitle, blue && styles.quickTitleBlue]}>{title}</Text>
        <Text style={[styles.quickDescription, blue && styles.quickDescriptionBlue]}>
          {description}
        </Text>
      </GlassCard>
    </Pressable>
  );
});
const PrescriptionMetric = memo(function ({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.prescriptionMetric}>
      <Text style={styles.prescriptionMetricLabel}>{label}</Text>
      <Text style={styles.prescriptionMetricValue}>{value}</Text>
    </View>
  );
});
const styles = StyleSheet.create({
  homeHeader: {
    minHeight: 50,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  greetingSmall: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
  },
  greetingTitle: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 25,
    fontWeight: '800',
    letterSpacing: -0.7,
    marginTop: 3,
  },
  smallBrand: {
    width: 42,
    height: 42,
    borderRadius: 21,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.blueSoft,
  },
  scoreCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    overflow: 'hidden',
  },
  scoreHalo: {
    position: 'absolute',
    width: 145,
    height: 145,
    borderRadius: 73,
    left: -48,
    top: -46,
    backgroundColor: colors.greenSoft,
    opacity: 0.58,
  },
  scoreCopy: {
    flex: 1,
    gap: 6,
  },
  scoreTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    flexWrap: 'wrap',
    gap: 6,
  },
  scoreTitle: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 17,
    fontWeight: '800',
  },
  scoreDescription: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
    lineHeight: 18,
  },
  detailLink: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    alignSelf: 'flex-start',
    paddingVertical: 4,
  },
  detailLinkText: {
    color: colors.blue,
    fontFamily: fonts.body,
    fontSize: 12,
    fontWeight: '800',
  },
  warning: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    backgroundColor: colors.amberSoft,
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: colors.line,
    padding: spacing.md,
  },
  warningCopy: {
    flex: 1,
  },
  warningTitle: {
    color: colors.amberInk,
    fontFamily: fonts.body,
    fontSize: 13,
    fontWeight: '800',
  },
  warningText: {
    color: colors.amberInk,
    fontFamily: fonts.body,
    fontSize: 11,
    marginTop: 2,
  },
  quickGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  quickAction: {
    width: '48%',
  },
  quickActionCard: {
    minHeight: 126,
    padding: spacing.md,
    justifyContent: 'space-between',
  },
  quickActionBlue: {
    backgroundColor: colors.blueSoft,
    borderColor: colors.line,
  },
  quickIcon: {
    width: 39,
    height: 39,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.greenSoft,
  },
  quickIconBlue: {
    backgroundColor: colors.surface,
  },
  quickTitle: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontSize: 14,
    fontWeight: '800',
    marginTop: spacing.sm,
  },
  quickTitleBlue: {
    color: colors.ink,
  },
  quickDescription: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 11,
    marginTop: 2,
  },
  quickDescriptionBlue: {
    color: colors.muted,
  },
  nutritionGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  nutritionCard: {
    width: '48%',
    borderRadius: radii.md,
    padding: spacing.md,
    gap: 8,
  },
  nutritionLabel: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
  },
  nutritionValue: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 20,
    fontWeight: '800',
    letterSpacing: -0.5,
  },
  nutritionUnit: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 11,
    fontWeight: '600',
  },
  microTrack: {
    height: 5,
    backgroundColor: colors.surfaceMuted,
    borderRadius: radii.pill,
    overflow: 'hidden',
  },
  microFill: {
    height: '100%',
    borderRadius: radii.pill,
  },
  microFillCalories: {
    width: '65%',
    backgroundColor: colors.amber,
  },
  microFillProtein: {
    width: '45%',
    backgroundColor: colors.green,
  },
  microFillCarbs: {
    width: '80%',
    backgroundColor: colors.blue,
  },
  microFillFat: {
    width: '65%',
    backgroundColor: colors.red,
  },
  actionText: {
    color: colors.blue,
    fontFamily: fonts.body,
    fontSize: 12,
    fontWeight: '800',
  },
  records: {
    paddingVertical: 3,
  },
  recordRow: {
    minHeight: 72,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingVertical: 9,
  },
  emptyRecords: {
    paddingVertical: spacing.lg,
    alignItems: 'center',
  },
  emptyRecordsText: {
    color: colors.blue,
    fontFamily: fonts.body,
    fontSize: 12,
    fontWeight: '700',
  },
  recordEmoji: {
    width: 40,
    height: 40,
    borderRadius: 14,
    backgroundColor: colors.surfaceMuted,
    alignItems: 'center',
    justifyContent: 'center',
  },
  recordInfo: {
    flex: 1,
  },
  recordName: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontSize: 13,
    fontWeight: '800',
  },
  recordDetail: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 11,
    marginTop: 4,
  },
  prescription: {
    backgroundColor: colors.blueSoft,
  },
  prescriptionHead: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 7,
    flexWrap: 'wrap',
  },
  prescriptionTitle: {
    flex: 1,
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 17,
    fontWeight: '800',
  },
  prescriptionDescription: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
    lineHeight: 19,
    marginTop: spacing.sm,
  },
  prescriptionGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginTop: spacing.md,
    gap: 8,
  },
  prescriptionMetric: {
    width: '48%',
    gap: 3,
  },
  prescriptionMetricLabel: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 11,
  },
  prescriptionMetricValue: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontSize: 12,
    fontWeight: '800',
  },
});
