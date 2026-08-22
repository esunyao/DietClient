import React, { memo, useCallback, useEffect, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { useFocusEffect } from '@react-navigation/native';
import {
  Activity,
  ArrowRight,
  Camera,
  Check,
  CircleAlert,
  FileText,
  Heart,
  Sparkles,
  Target,
  TrendingUp,
  Utensils,
} from 'lucide-react-native';
import Animated, { useAnimatedStyle, useSharedValue, withRepeat, withSpring, withTiming } from 'react-native-reanimated';

import { durations, springGentle, timing } from '../../../shared/animation/config';
import type { HomeStackParamList } from '../../../navigation/types';
import { AppButton, AppScreen, GlassCard, MetricProgress, ScoreRing, SectionTitle, Tag, useToast } from '../../../shared/components';
import { colors, fonts, radii, shadows, spacing } from '../../../shared/theme/tokens';
import { nutriApi } from '../api/nutriApi';
import type { MealHistoryItem, NutrientValue } from '../api/nutriTypes';
import { localDateFromDate } from '../services/mealCapture';

type HomeProps = NativeStackScreenProps<HomeStackParamList, 'HomeMain'>;
type ScoreProps = NativeStackScreenProps<HomeStackParamList, 'ScoreDetail'>;

const StaticPageHeading = memo(function ({ eyebrow, title, description, icon }: { eyebrow: string; title: string; description: string; icon: React.ReactNode }) {
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

const MiniNutrition = memo(function ({ label, value, unit }: { label: string; value: string; unit: string }) {
  const fillStyle = label === '蛋白质'
    ? styles.microFillProtein
    : label === '碳水'
      ? styles.microFillCarbs
      : label === '脂肪'
        ? styles.microFillFat
        : styles.microFillCalories;

  return (
    <GlassCard style={styles.nutritionCard}>
      <Text style={styles.nutritionLabel}>{label}</Text>
      <Text style={styles.nutritionValue}>{value}<Text style={styles.nutritionUnit}> {unit}</Text></Text>
      <View style={styles.microTrack}><View style={[styles.microFill, fillStyle]} /></View>
    </GlassCard>
  );
});

const RecordRow = memo(function ({ emoji, name, detail, tag, tone = 'green', onPress }: { emoji: string; name: string; detail: string; tag: string; tone?: 'green' | 'amber'; onPress?: () => void }) {
  return (
    <Pressable accessibilityRole={onPress ? 'button' : undefined} onPress={onPress} style={styles.recordRow}>
      <View style={styles.recordEmoji}><Text>{emoji}</Text></View>
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
  return ({ breakfast: '🥣', lunch: '🥗', dinner: '🍲', snack: '🍎', other: '🍽️' })[meal.mealType];
}

export function HomeScreen({ navigation }: HomeProps) {
  const [todayMeals, setTodayMeals] = useState<MealHistoryItem[]>([]);
  const [todayNutrients, setTodayNutrients] = useState<NutrientValue[]>([]);
  const [loadingMeals, setLoadingMeals] = useState(true);
  const today = localDateFromDate();
  const openDiet = useCallback((screen?: 'Recognition' | 'MealHistory' | 'MealDetail', params?: { mealId: string }) => {
    const tabNavigation = navigation.getParent() as unknown as { navigate: (name: string, params?: unknown) => void } | undefined;
    if (!screen || screen === 'Recognition') {
      tabNavigation?.navigate('RecognitionTab');
      return;
    }
    tabNavigation?.navigate('RecognitionTab', { screen, params });
  }, [navigation]);
  const loadToday = useCallback(async () => {
    setLoadingMeals(true);
    try {
      const [summary, mealPage] = await Promise.all([
        nutriApi.getDailySummary(today),
        nutriApi.listMeals({ dateFrom: today, dateTo: today, pageSize: 20 }),
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

  useFocusEffect(useCallback(() => { loadToday(); }, [loadToday]));

  return (
    <AppScreen>
      <View style={styles.homeHeader}>
        <View>
          <Text style={styles.greetingSmall}>2026 年 8 月 5 日 · 下午好</Text>
          <Text style={styles.greetingTitle}>今天吃得怎么样？</Text>
        </View>
        <View style={styles.smallBrand}><Utensils color={colors.blue} size={19} /></View>
      </View>

      <GlassCard style={styles.scoreCard}>
        <View style={styles.scoreHalo} />
        <ScoreRing score={78} />
        <View style={styles.scoreCopy}>
          <View style={styles.scoreTitleRow}>
            <Text style={styles.scoreTitle}>状态良好</Text>
            <Tag label="今日达标" tone="green" />
          </View>
          <Text style={styles.scoreDescription}>热量适中，蛋白质偏低。晚餐适合补充豆腐、鱼类或鸡胸肉。</Text>
          <Pressable onPress={() => navigation.navigate('ScoreDetail')} style={styles.detailLink}>
            <Text style={styles.detailLinkText}>查看健康评分</Text><ArrowRight color={colors.blue} size={14} />
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
        <QuickAction icon={<Camera color={colors.blue} size={22} />} title="识别这一餐" description="拍照 · AI 分析" blue onPress={() => openDiet()} />
        <QuickAction icon={<Sparkles color={colors.green} size={22} />} title="下一餐处方" description="AI 配餐" />
        <QuickAction icon={<Target color={colors.blue} size={22} />} title="今日目标" description="调整目标" />
        <QuickAction icon={<TrendingUp color={colors.blue} size={22} />} title="历史追踪" description="饮食 & 身体" />
      </View>

      <SectionTitle title="今日营养摄入" detail={loadingMeals ? '正在加载…' : todayMeals.length ? `${todayMeals.length} 餐已记录` : '还没有餐食记录'} />
      <View style={styles.nutritionGrid}>
        <MiniNutrition label="热量" value={formatNutrient(nutrientValue(todayNutrients, 'ENERGY_KCAL'))} unit="kcal" />
        <MiniNutrition label="蛋白质" value={formatNutrient(nutrientValue(todayNutrients, 'PROTEIN'))} unit="g" />
        <MiniNutrition label="碳水" value={formatNutrient(nutrientValue(todayNutrients, 'CARBOHYDRATE'))} unit="g" />
        <MiniNutrition label="脂肪" value={formatNutrient(nutrientValue(todayNutrients, 'FAT'))} unit="g" />
      </View>

      <SectionTitle title="今日饮食记录" action={<Pressable onPress={() => openDiet('MealHistory')}><Text style={styles.actionText}>全部记录</Text></Pressable>} />
      <GlassCard style={styles.records}>
        {todayMeals.map(meal => <RecordRow key={meal.mealId} emoji={recordEmoji(meal)} name={meal.notes || '已分析餐食'} detail={`${meal.mealType === 'breakfast' ? '早餐' : meal.mealType === 'lunch' ? '午餐' : meal.mealType === 'dinner' ? '晚餐' : meal.mealType === 'snack' ? '加餐' : '其他'} · ${new Date(meal.consumedAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })} · ${formatNutrient(nutrientValue(meal.nutrients, 'ENERGY_KCAL'))} kcal`} tag="已分析" tone="green" onPress={() => openDiet('MealDetail', { mealId: meal.mealId })} />)}
        {!loadingMeals && !todayMeals.length ? <Pressable onPress={() => openDiet()} style={styles.emptyRecords}><Text style={styles.emptyRecordsText}>今天还没有餐食记录，点击开始记录。</Text></Pressable> : null}
      </GlassCard>

      <GlassCard style={styles.prescription}>
        <View style={styles.prescriptionHead}><Sparkles color={colors.blue} size={19} /><Text style={styles.prescriptionTitle}>AI 下一餐处方</Text><Tag label="晚餐推荐" tone="green" /></View>
        <Text style={styles.prescriptionDescription}>基于演示健康画像与今日累计营养，推荐低钠、高蛋白的一餐。</Text>
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

const QuickAction = memo(function ({ icon, title, description, blue = false, onPress }: { icon: React.ReactNode; title: string; description: string; blue?: boolean; onPress?: () => void }) {
  return (
    <Pressable accessibilityRole={onPress ? 'button' : undefined} onPress={onPress} style={styles.quickAction}>
    <GlassCard style={[styles.quickActionCard, blue && styles.quickActionBlue]}>
      <View style={[styles.quickIcon, blue && styles.quickIconBlue]}>{icon}</View>
      <Text style={[styles.quickTitle, blue && styles.quickTitleBlue]}>{title}</Text>
      <Text style={[styles.quickDescription, blue && styles.quickDescriptionBlue]}>{description}</Text>
    </GlassCard>
    </Pressable>
  );
});

const PrescriptionMetric = memo(function ({ label, value }: { label: string; value: string }) {
  return <View style={styles.prescriptionMetric}><Text style={styles.prescriptionMetricLabel}>{label}</Text><Text style={styles.prescriptionMetricValue}>{value}</Text></View>;
});

export function RecognitionScreen() {
  const { show } = useToast();
  return (
    <AppScreen>
      <StaticPageHeading eyebrow="饮食记录" title="识别这一餐" description="拍照、上传图片或手动添加菜品。当前为静态演示流程。" icon={<Camera color={colors.blue} size={15} />} />
      <GlassCard style={styles.scanCard}>
        <View style={styles.scanFrame}><Camera color={colors.blue} size={33} /><ScanLine /></View>
        <Text style={styles.scanTitle}>把餐盘放进取景框</Text>
        <Text style={styles.scanDescription}>清晰拍摄食物整体，AI 将识别菜品、份量与营养组成。</Text>
        <AppButton label="选择演示图片" onPress={() => show('这是静态识别页面，尚未上传图片。')} />
      </GlassCard>
      <SectionTitle title="演示识别结果" detail="家庭午餐 · 识别可信度 96%" />
      <GlassCard style={styles.resultCard}>
        <View style={styles.resultLead}><View style={styles.resultDish}><Text style={styles.dishEmoji}>🥗</Text></View><View style={styles.resultText}><Text style={styles.resultName}>鸡胸肉藜麦沙拉</Text><Text style={styles.resultMeta}>约 320g · 肉菜 / 主食 / 低盐</Text></View><Tag label="96%" tone="green" /></View>
        <View style={styles.divider} />
        <View style={styles.resultStats}><ResultStat label="热量" value="570" unit="kcal" /><ResultStat label="蛋白质" value="42" unit="g" /><ResultStat label="钠" value="480" unit="mg" /></View>
      </GlassCard>
      <GlassCard>
        <SectionTitle title="营养解析" />
        <View style={styles.metricList}><MetricProgress label="蛋白质充足度" value={88} color={colors.green} /><MetricProgress label="膳食纤维" value={74} color={colors.blue} /><MetricProgress label="钠控制" value={68} color={colors.amber} /></View>
      </GlassCard>
    </AppScreen>
  );
}

const ResultStat = memo(function ({ label, value, unit }: { label: string; value: string; unit: string }) {
  return <View style={styles.resultStat}><Text style={styles.resultStatValue}>{value}<Text style={styles.resultStatUnit}> {unit}</Text></Text><Text style={styles.resultStatLabel}>{label}</Text></View>;
});

export function MealPlanScreen() {
  const { show } = useToast();
  const [plan, setPlan] = useState('A');
  const descriptions: Record<string, string> = { A: '低钠高蛋白 · 适合补足今日蛋白质', B: '清淡饱腹 · 适合控制晚餐热量', C: '快捷易做 · 适合工作日晚间' };
  return (
    <AppScreen>
      <StaticPageHeading eyebrow="AI 配餐" title="下一餐处方" description="模拟展示基于健康画像与当日摄入生成的三种可选方案。" icon={<Sparkles color={colors.blue} size={15} />} />
      <GlassCard style={styles.planHero}>
        <View style={styles.planHeroTop}><View style={styles.planSpark}><Sparkles color={colors.inverse} size={22} /></View><View style={styles.planHeroText}><Text style={styles.planHeroTitle}>晚餐营养处方</Text><Text style={styles.planHeroDescription}>{descriptions[plan]}</Text></View><Tag label={`方案 ${plan}`} tone="green" /></View>
        <View style={styles.planSwitch}>{['A', 'B', 'C'].map(item => <Pressable key={item} onPress={() => setPlan(item)} style={[styles.planSwitchItem, plan === item && styles.planSwitchItemActive]}><Text style={[styles.planSwitchText, plan === item && styles.planSwitchTextActive]}>方案 {item}</Text></Pressable>)}</View>
      </GlassCard>
      <View style={styles.planStats}><PlanStat label="目标热量" value="450" unit="kcal" /><PlanStat label="蛋白质" value="38" unit="g" /><PlanStat label="预计用时" value="25" unit="分钟" /></View>
      <SectionTitle title="推荐食材" detail="可按饮食偏好替换" />
      <GlassCard style={styles.ingredientList}>
        <Ingredient emoji="🧈" name="嫩豆腐" note="优质植物蛋白 · 180g" />
        <Ingredient emoji="🥦" name="西兰花" note="高纤维 · 焯水少盐" />
        <Ingredient emoji="🍚" name="糙米饭" note="复合碳水 · 100g" />
        <Ingredient emoji="🐟" name="清蒸鲈鱼" note="补充优质蛋白 · 100g" />
      </GlassCard>
      <GlassCard>
        <SectionTitle title="为什么这样搭配" />
        <View style={styles.reasonRow}><Check color={colors.green} size={17} /><Text style={styles.reasonText}>补足今日蛋白质缺口，同时控制钠与精制碳水。</Text></View>
        <View style={styles.reasonRow}><Check color={colors.green} size={17} /><Text style={styles.reasonText}>食材可在常见菜场或超市购买，烹饪时以清蒸、焯拌为主。</Text></View>
        <AppButton label="切换一组替代食材" variant="secondary" onPress={() => show('已切换演示食材，真实替换将在 AI 服务接入后开放。')} style={styles.marginTop} />
      </GlassCard>
    </AppScreen>
  );
}

const PlanStat = memo(function ({ label, value, unit }: { label: string; value: string; unit: string }) {
  return <GlassCard style={styles.planStat}><Text style={styles.planStatValue}>{value}<Text style={styles.planStatUnit}> {unit}</Text></Text><Text style={styles.planStatLabel}>{label}</Text></GlassCard>;
});

const Ingredient = memo(function ({ emoji, name, note }: { emoji: string; name: string; note: string }) {
  return <View style={styles.ingredient}><Text style={styles.ingredientEmoji}>{emoji}</Text><View><Text style={styles.ingredientName}>{name}</Text><Text style={styles.ingredientNote}>{note}</Text></View></View>;
});

export function TrendsScreen() {
  const [range, setRange] = useState('周');
  const values = range === '周' ? [72, 75, 73, 77, 76, 80, 78] : range === '月' ? [68, 72, 74, 76, 78, 79] : [62, 69, 73, 78];
  return (
    <AppScreen>
      <StaticPageHeading eyebrow="数据统计" title="健康趋势" description="模拟展示饮食执行与身体状态的阶段性变化。" icon={<TrendingUp color={colors.blue} size={15} />} />
      <View style={styles.rangeSwitch}>{['周', '月', '季'].map(item => <Pressable key={item} onPress={() => setRange(item)} style={[styles.rangeItem, range === item && styles.rangeItemActive]}><Text style={[styles.rangeText, range === item && styles.rangeTextActive]}>{item}</Text></Pressable>)}</View>
      <GlassCard>
        <View style={styles.chartHead}><View><Text style={styles.chartTitle}>综合健康评分</Text><Text style={styles.chartDescription}>当前 78 · 较周期开始 +6</Text></View><Tag label="稳步改善" tone="green" /></View>
        <View style={styles.chart}>{values.map((value, index) => <View key={`${value}-${index}`} style={styles.barColumn}><Text style={styles.barValue}>{value}</Text><GrowingBar value={value} color={index === values.length - 1 ? colors.green : colors.blue} /><Text style={styles.barLabel}>{index + 1}</Text></View>)}</View>
      </GlassCard>
      <SectionTitle title="本周期执行反馈" />
      <GlassCard style={styles.metricList}>
        <MetricProgress label="饮食记录完成率" value={86} color={colors.green} rightLabel="86%" />
        <MetricProgress label="营养目标达标率" value={74} color={colors.blue} rightLabel="74%" />
        <MetricProgress label="餐食满意度" value={89} color={colors.green} rightLabel="4.5 / 5" />
      </GlassCard>
      <GlassCard style={styles.trendInsight}><Heart color={colors.red} size={20} /><View style={styles.trendInsightCopy}><Text style={styles.trendInsightTitle}>本周健康提示</Text><Text style={styles.trendInsightText}>蛋白质摄入持续改善；周末仍建议留意外卖和调味料中的隐性钠。</Text></View></GlassCard>
    </AppScreen>
  );
}

export function ReportsScreen() {
  const { show } = useToast();
  return (
    <AppScreen>
      <StaticPageHeading eyebrow="健康报告" title="报告中心" description="将阶段性饮食与健康数据整理为可读结论。当前为静态预览。" icon={<FileText color={colors.blue} size={15} />} />
      <GlassCard style={styles.reportHero}>
        <View style={styles.reportIcon}><FileText color={colors.inverse} size={23} /></View>
        <View style={styles.reportCopy}><Text style={styles.reportTitle}>本周营养健康报告</Text><Text style={styles.reportDescription}>2026.07.30 – 2026.08.05 · 已生成</Text></View>
        <Tag label="最新" tone="green" />
      </GlassCard>
      <GlassCard>
        <SectionTitle title="本期结论" detail="根据演示数据生成" />
        <View style={styles.conclusion}><View style={[styles.conclusionBullet, { backgroundColor: colors.green }]} /><Text style={styles.conclusionText}>饮食记录执行率 86%，较上周提高 12%。</Text></View>
        <View style={styles.conclusion}><View style={[styles.conclusionBullet, { backgroundColor: colors.amber }]} /><Text style={styles.conclusionText}>蛋白质改善明显，但晚餐钠摄入仍需要控制。</Text></View>
        <View style={styles.conclusion}><View style={[styles.conclusionBullet, { backgroundColor: colors.blue }]} /><Text style={styles.conclusionText}>建议保持清蒸、炖煮的烹饪方式并持续记录。</Text></View>
        <AppButton label="查看演示报告" onPress={() => show('真实报告将在报告服务接入后生成。')} style={styles.marginTop} />
      </GlassCard>
      <SectionTitle title="历史报告" />
      <GlassCard style={styles.historyCard}><HistoryRow title="7 月营养阶段报告" date="2026.07.31" score="75 分" /><HistoryRow title="7 月第 3 周健康摘要" date="2026.07.24" score="72 分" /><HistoryRow title="首次健康画像报告" date="2026.07.01" score="—" /></GlassCard>
    </AppScreen>
  );
}

const HistoryRow = memo(function ({ title, date, score }: { title: string; date: string; score: string }) {
  return <View style={styles.historyRow}><View style={styles.historyDoc}><FileText color={colors.blue} size={17} /></View><View style={styles.historyText}><Text style={styles.historyTitle}>{title}</Text><Text style={styles.historyDate}>{date}</Text></View><Text style={styles.historyScore}>{score}</Text></View>;
});

export function ScoreDetailScreen({ navigation }: ScoreProps) {
  return (
    <AppScreen>
      <View style={styles.scoreDetailHeader}><Pressable onPress={() => navigation.goBack()}><Text style={styles.backLink}>← 返回首页</Text></Pressable></View>
      <View style={styles.scoreDetailTop}><ScoreRing score={78} size={150} /><Text style={styles.scoreDetailTitle}>你的健康状态良好</Text><Text style={styles.scoreDetailDescription}>评分由热量、营养均衡、微量营养与风险控制四个维度组成。</Text></View>
      <GlassCard style={styles.metricList}>
        <MetricProgress label="热量适配度" value={85} color={colors.green} rightLabel="85 分" />
        <MetricProgress label="营养均衡度" value={72} color={colors.amber} rightLabel="72 分" />
        <MetricProgress label="微量营养素充足度" value={68} color={colors.blue} rightLabel="68 分" />
        <MetricProgress label="健康风险控制" value={90} color={colors.green} rightLabel="90 分" />
      </GlassCard>
      <GlassCard style={styles.scoreTip}><Activity color={colors.blue} size={21} /><View style={styles.scoreTipCopy}><Text style={styles.scoreTipTitle}>下一步建议</Text><Text style={styles.scoreTipText}>晚餐增加一份优质蛋白，并避免额外酱料。评分页是静态示例，不会写入健康数据。</Text></View></GlassCard>
    </AppScreen>
  );
}

/** 识别页取景框内的扫描线：reanimated 驱动 translateY 上下往返。 */
function ScanLine() {
  const y = useSharedValue(0);
  useEffect(() => {
    y.value = withRepeat(withTiming(44, timing(durations.scanSweep)), -1, true);
  }, [y]);
  const style = useAnimatedStyle(() => ({ transform: [{ translateY: y.value }] }));
  return <Animated.View style={[styles.scanLine, style]} />;
}

/** 趋势图柱：scaleY 从底部生长（transform 驱动，不动 height）。 */
function GrowingBar({ value, color }: { value: number; color: string }) {
  const scale = useSharedValue(0);
  useEffect(() => {
    scale.value = withSpring(1, springGentle);
  }, [scale]);
  const style = useAnimatedStyle(() => ({
    transformOrigin: 'bottom center',
    transform: [{ scaleY: scale.value }],
  }));
  return <Animated.View style={[styles.bar, { height: `${value}%`, backgroundColor: color }, style]} />;
}

const styles = StyleSheet.create({
  pageHeading: { gap: 6 },
  eyebrowRow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  eyebrowIcon: { width: 24, height: 24, borderRadius: 12, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.blueSoft },
  eyebrow: { color: colors.blue, fontFamily: fonts.body, fontSize: 12, fontWeight: '800' },
  pageTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 28, fontWeight: '800', letterSpacing: -0.8 },
  pageDescription: { color: colors.muted, fontFamily: fonts.body, fontSize: 13, lineHeight: 20 },
  homeHeader: { minHeight: 50, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  greetingSmall: { color: colors.muted, fontFamily: fonts.body, fontSize: 12 },
  greetingTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 25, fontWeight: '800', letterSpacing: -0.7, marginTop: 3 },
  smallBrand: { width: 42, height: 42, borderRadius: 21, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.blueSoft },
  scoreCard: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, overflow: 'hidden' },
  scoreHalo: { position: 'absolute', width: 145, height: 145, borderRadius: 73, left: -48, top: -46, backgroundColor: colors.greenSoft, opacity: 0.58 },
  scoreCopy: { flex: 1, gap: 6 },
  scoreTitleRow: { flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap', gap: 6 },
  scoreTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 17, fontWeight: '800' },
  scoreDescription: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, lineHeight: 18 },
  detailLink: { flexDirection: 'row', alignItems: 'center', gap: 3, alignSelf: 'flex-start', paddingVertical: 4 },
  detailLinkText: { color: colors.blue, fontFamily: fonts.body, fontSize: 12, fontWeight: '800' },
  warning: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, backgroundColor: colors.amberSoft, borderRadius: radii.md, borderWidth: 1, borderColor: colors.line, padding: spacing.md },
  warningCopy: { flex: 1 },
  warningTitle: { color: colors.amberInk, fontFamily: fonts.body, fontSize: 13, fontWeight: '800' },
  warningText: { color: colors.amberInk, fontFamily: fonts.body, fontSize: 11, marginTop: 2 },
  quickGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  quickAction: { width: '48%' },
  quickActionCard: { minHeight: 126, padding: spacing.md, justifyContent: 'space-between' },
  quickActionBlue: { backgroundColor: colors.blueSoft, borderColor: colors.line },
  quickIcon: { width: 39, height: 39, borderRadius: 14, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.greenSoft },
  quickIconBlue: { backgroundColor: colors.surface },
  quickTitle: { color: colors.ink, fontFamily: fonts.body, fontSize: 14, fontWeight: '800', marginTop: spacing.sm },
  quickTitleBlue: { color: colors.ink },
  quickDescription: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, marginTop: 2 },
  quickDescriptionBlue: { color: colors.muted },
  nutritionGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  nutritionCard: { width: '48%', borderRadius: radii.md, padding: spacing.md, gap: 8 },
  nutritionLabel: { color: colors.muted, fontFamily: fonts.body, fontSize: 12 },
  nutritionValue: { color: colors.ink, fontFamily: fonts.display, fontSize: 20, fontWeight: '800', letterSpacing: -0.5 },
  nutritionUnit: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, fontWeight: '600' },
  microTrack: { height: 5, backgroundColor: colors.surfaceMuted, borderRadius: radii.pill, overflow: 'hidden' },
  microFill: { height: '100%', borderRadius: radii.pill },
  microFillCalories: { width: '65%', backgroundColor: colors.amber },
  microFillProtein: { width: '45%', backgroundColor: colors.green },
  microFillCarbs: { width: '80%', backgroundColor: colors.blue },
  microFillFat: { width: '65%', backgroundColor: colors.red },
  actionText: { color: colors.blue, fontFamily: fonts.body, fontSize: 12, fontWeight: '800' },
  records: { paddingVertical: 3 },
  recordRow: { minHeight: 72, flexDirection: 'row', alignItems: 'center', gap: spacing.sm, paddingVertical: 9 },
  emptyRecords: { paddingVertical: spacing.lg, alignItems: 'center' },
  emptyRecordsText: { color: colors.blue, fontFamily: fonts.body, fontSize: 12, fontWeight: '700' },
  recordEmoji: { width: 40, height: 40, borderRadius: 14, backgroundColor: colors.surfaceMuted, alignItems: 'center', justifyContent: 'center' },
  recordInfo: { flex: 1 },
  recordName: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '800' },
  recordDetail: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, marginTop: 4 },
  prescription: { backgroundColor: colors.blueSoft },
  prescriptionHead: { flexDirection: 'row', alignItems: 'center', gap: 7, flexWrap: 'wrap' },
  prescriptionTitle: { flex: 1, color: colors.ink, fontFamily: fonts.display, fontSize: 17, fontWeight: '800' },
  prescriptionDescription: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, lineHeight: 19, marginTop: spacing.sm },
  prescriptionGrid: { flexDirection: 'row', flexWrap: 'wrap', marginTop: spacing.md, gap: 8 },
  prescriptionMetric: { width: '48%', gap: 3 },
  prescriptionMetricLabel: { color: colors.muted, fontFamily: fonts.body, fontSize: 11 },
  prescriptionMetricValue: { color: colors.ink, fontFamily: fonts.body, fontSize: 12, fontWeight: '800' },
  scanCard: { alignItems: 'center', paddingVertical: spacing.xl },
  scanFrame: { width: 130, height: 130, borderRadius: radii.lg, borderWidth: 1.5, borderStyle: 'dashed', borderColor: colors.blue, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.surfaceMuted, overflow: 'hidden' },
  scanLine: { position: 'absolute', left: 17, right: 17, top: 63, height: 2, backgroundColor: colors.green, opacity: 0.7 },
  scanTitle: { color: colors.ink, fontFamily: fonts.display, fontWeight: '800', fontSize: 18, marginTop: spacing.lg },
  scanDescription: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, lineHeight: 19, textAlign: 'center', marginTop: spacing.sm, marginBottom: spacing.lg },
  resultCard: { gap: spacing.md },
  resultLead: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  resultDish: { width: 52, height: 52, borderRadius: 18, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.greenSoft },
  dishEmoji: { fontSize: 24 },
  resultText: { flex: 1 },
  resultName: { color: colors.ink, fontFamily: fonts.body, fontWeight: '800', fontSize: 15 },
  resultMeta: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, marginTop: 4 },
  divider: { height: 1, backgroundColor: colors.line },
  resultStats: { flexDirection: 'row', justifyContent: 'space-around' },
  resultStat: { alignItems: 'center' },
  resultStatValue: { color: colors.ink, fontFamily: fonts.display, fontWeight: '800', fontSize: 17 },
  resultStatUnit: { color: colors.muted, fontSize: 10, fontFamily: fonts.body },
  resultStatLabel: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, marginTop: 3 },
  metricList: { gap: spacing.lg },
  planHero: { backgroundColor: colors.blueSoft },
  planHeroTop: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  planSpark: { width: 44, height: 44, borderRadius: 16, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.blue },
  planHeroText: { flex: 1 },
  planHeroTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 17, fontWeight: '800' },
  planHeroDescription: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, marginTop: 3 },
  planSwitch: { flexDirection: 'row', backgroundColor: colors.surfaceMuted, borderRadius: radii.pill, padding: 3, marginTop: spacing.lg },
  planSwitchItem: { flex: 1, alignItems: 'center', borderRadius: radii.pill, paddingVertical: 8 },
  planSwitchItemActive: { backgroundColor: colors.surface, boxShadow: shadows.soft },
  planSwitchText: { color: colors.muted, fontFamily: fonts.body, fontWeight: '700', fontSize: 12 },
  planSwitchTextActive: { color: colors.blue },
  planStats: { flexDirection: 'row', gap: spacing.sm },
  planStat: { flex: 1, alignItems: 'center', paddingVertical: spacing.md, paddingHorizontal: 5, borderRadius: radii.md },
  planStatValue: { color: colors.ink, fontFamily: fonts.display, fontSize: 18, fontWeight: '800' },
  planStatUnit: { color: colors.muted, fontFamily: fonts.body, fontSize: 10 },
  planStatLabel: { color: colors.muted, fontFamily: fonts.body, fontSize: 10, marginTop: 3 },
  ingredientList: { paddingVertical: 4 },
  ingredient: { minHeight: 58, flexDirection: 'row', alignItems: 'center', gap: spacing.md, paddingVertical: 7 },
  ingredientEmoji: { fontSize: 23 },
  ingredientName: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '800' },
  ingredientNote: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, marginTop: 3 },
  reasonRow: { flexDirection: 'row', alignItems: 'flex-start', gap: spacing.sm, marginTop: spacing.md },
  reasonText: { flex: 1, color: colors.muted, fontFamily: fonts.body, fontSize: 12, lineHeight: 19 },
  marginTop: { marginTop: spacing.lg },
  rangeSwitch: { flexDirection: 'row', alignSelf: 'flex-start', backgroundColor: colors.surfaceMuted, borderRadius: radii.pill, padding: 3 },
  rangeItem: { minWidth: 52, alignItems: 'center', borderRadius: radii.pill, paddingVertical: 7, paddingHorizontal: spacing.sm },
  rangeItemActive: { backgroundColor: colors.surface },
  rangeText: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, fontWeight: '700' },
  rangeTextActive: { color: colors.blue },
  chartHead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', gap: spacing.sm },
  chartTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 17, fontWeight: '800' },
  chartDescription: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, marginTop: 4 },
  chart: { height: 178, flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'space-around', gap: 5, marginTop: spacing.xl, borderBottomWidth: 1, borderColor: colors.line },
  barColumn: { flex: 1, height: '100%', justifyContent: 'flex-end', alignItems: 'center', gap: 4 },
  bar: { width: '66%', minHeight: 10, borderTopLeftRadius: 8, borderTopRightRadius: 8, opacity: 0.92 },
  barValue: { color: colors.muted, fontFamily: fonts.mono, fontSize: 10 },
  barLabel: { color: colors.muted, fontFamily: fonts.body, fontSize: 10, paddingBottom: 4 },
  trendInsight: { flexDirection: 'row', gap: spacing.md, backgroundColor: colors.redSoft },
  trendInsightCopy: { flex: 1 },
  trendInsightTitle: { color: colors.ink, fontFamily: fonts.body, fontWeight: '800', fontSize: 14 },
  trendInsightText: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, lineHeight: 19, marginTop: 4 },
  reportHero: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, backgroundColor: colors.blueSoft },
  reportIcon: { width: 46, height: 46, borderRadius: 16, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.blue },
  reportCopy: { flex: 1 },
  reportTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 16, fontWeight: '800' },
  reportDescription: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, marginTop: 4 },
  conclusion: { flexDirection: 'row', alignItems: 'flex-start', gap: spacing.sm, marginTop: spacing.md },
  conclusionBullet: { width: 8, height: 8, borderRadius: 4, marginTop: 5 },
  conclusionText: { flex: 1, color: colors.muted, fontFamily: fonts.body, fontSize: 12, lineHeight: 19 },
  historyCard: { paddingVertical: 4 },
  historyRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, minHeight: 60, paddingVertical: 7 },
  historyDoc: { width: 35, height: 35, borderRadius: 12, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.blueSoft },
  historyText: { flex: 1 },
  historyTitle: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '800' },
  historyDate: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, marginTop: 3 },
  historyScore: { color: colors.green, fontFamily: fonts.body, fontSize: 12, fontWeight: '800' },
  scoreDetailHeader: { minHeight: 28 },
  backLink: { color: colors.blue, fontFamily: fonts.body, fontSize: 13, fontWeight: '700' },
  scoreDetailTop: { alignItems: 'center', paddingVertical: spacing.md },
  scoreDetailTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 22, fontWeight: '800', marginTop: spacing.lg },
  scoreDetailDescription: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, lineHeight: 19, textAlign: 'center', marginTop: spacing.sm, paddingHorizontal: spacing.md },
  scoreTip: { flexDirection: 'row', gap: spacing.md, backgroundColor: colors.blueSoft },
  scoreTipCopy: { flex: 1 },
  scoreTipTitle: { color: colors.ink, fontFamily: fonts.body, fontSize: 14, fontWeight: '800' },
  scoreTipText: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, lineHeight: 19, marginTop: 4 },
});
