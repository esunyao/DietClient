import React, { memo, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Check, Sparkles } from 'lucide-react-native';
import {
  AppButton,
  AppScreen,
  GlassCard,
  SectionTitle,
  Tag,
  useToast,
} from '../../../shared/components';
import { colors, fonts, radii, shadows, spacing } from '../../../shared/theme/tokens';
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
export function MealPlanScreen() {
  const { show } = useToast();
  const [plan, setPlan] = useState('A');
  const descriptions: Record<string, string> = {
    A: '低钠高蛋白 · 适合补足今日蛋白质',
    B: '清淡饱腹 · 适合控制晚餐热量',
    C: '快捷易做 · 适合工作日晚间',
  };
  return (
    <AppScreen>
      <StaticPageHeading
        eyebrow="AI 配餐"
        title="下一餐处方"
        description="模拟展示基于健康画像与当日摄入生成的三种可选方案。"
        icon={<Sparkles color={colors.blue} size={15} />}
      />
      <GlassCard style={styles.planHero}>
        <View style={styles.planHeroTop}>
          <View style={styles.planSpark}>
            <Sparkles color={colors.inverse} size={22} />
          </View>
          <View style={styles.planHeroText}>
            <Text style={styles.planHeroTitle}>晚餐营养处方</Text>
            <Text style={styles.planHeroDescription}>{descriptions[plan]}</Text>
          </View>
          <Tag label={`方案 ${plan}`} tone="green" />
        </View>
        <View style={styles.planSwitch}>
          {['A', 'B', 'C'].map(item => (
            <Pressable
              key={item}
              onPress={() => setPlan(item)}
              style={[styles.planSwitchItem, plan === item && styles.planSwitchItemActive]}
            >
              <Text style={[styles.planSwitchText, plan === item && styles.planSwitchTextActive]}>
                方案 {item}
              </Text>
            </Pressable>
          ))}
        </View>
      </GlassCard>
      <View style={styles.planStats}>
        <PlanStat label="目标热量" value="450" unit="kcal" />
        <PlanStat label="蛋白质" value="38" unit="g" />
        <PlanStat label="预计用时" value="25" unit="分钟" />
      </View>
      <SectionTitle title="推荐食材" detail="可按饮食偏好替换" />
      <GlassCard style={styles.ingredientList}>
        <Ingredient emoji="🧈" name="嫩豆腐" note="优质植物蛋白 · 180g" />
        <Ingredient emoji="🥦" name="西兰花" note="高纤维 · 焯水少盐" />
        <Ingredient emoji="🍚" name="糙米饭" note="复合碳水 · 100g" />
        <Ingredient emoji="🐟" name="清蒸鲈鱼" note="补充优质蛋白 · 100g" />
      </GlassCard>
      <GlassCard>
        <SectionTitle title="为什么这样搭配" />
        <View style={styles.reasonRow}>
          <Check color={colors.green} size={17} />
          <Text style={styles.reasonText}>补足今日蛋白质缺口，同时控制钠与精制碳水。</Text>
        </View>
        <View style={styles.reasonRow}>
          <Check color={colors.green} size={17} />
          <Text style={styles.reasonText}>
            食材可在常见菜场或超市购买，烹饪时以清蒸、焯拌为主。
          </Text>
        </View>
        <AppButton
          label="切换一组替代食材"
          variant="secondary"
          onPress={() => show('已切换演示食材，真实替换将在 AI 服务接入后开放。')}
          style={styles.marginTop}
        />
      </GlassCard>
    </AppScreen>
  );
}
const PlanStat = memo(function ({
  label,
  value,
  unit,
}: {
  label: string;
  value: string;
  unit: string;
}) {
  return (
    <GlassCard style={styles.planStat}>
      <Text style={styles.planStatValue}>
        {value}
        <Text style={styles.planStatUnit}> {unit}</Text>
      </Text>
      <Text style={styles.planStatLabel}>{label}</Text>
    </GlassCard>
  );
});
const Ingredient = memo(function ({
  emoji,
  name,
  note,
}: {
  emoji: string;
  name: string;
  note: string;
}) {
  return (
    <View style={styles.ingredient}>
      <Text style={styles.ingredientEmoji}>{emoji}</Text>
      <View>
        <Text style={styles.ingredientName}>{name}</Text>
        <Text style={styles.ingredientNote}>{note}</Text>
      </View>
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
  planHero: {
    backgroundColor: colors.blueSoft,
  },
  planHeroTop: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  planSpark: {
    width: 44,
    height: 44,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.blue,
  },
  planHeroText: {
    flex: 1,
  },
  planHeroTitle: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 17,
    fontWeight: '800',
  },
  planHeroDescription: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 11,
    marginTop: 3,
  },
  planSwitch: {
    flexDirection: 'row',
    backgroundColor: colors.surfaceMuted,
    borderRadius: radii.pill,
    padding: 3,
    marginTop: spacing.lg,
  },
  planSwitchItem: {
    flex: 1,
    alignItems: 'center',
    borderRadius: radii.pill,
    paddingVertical: 8,
  },
  planSwitchItemActive: {
    backgroundColor: colors.surface,
    boxShadow: shadows.soft,
  },
  planSwitchText: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontWeight: '700',
    fontSize: 12,
  },
  planSwitchTextActive: {
    color: colors.blue,
  },
  planStats: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  planStat: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: spacing.md,
    paddingHorizontal: 5,
    borderRadius: radii.md,
  },
  planStatValue: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 18,
    fontWeight: '800',
  },
  planStatUnit: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 10,
  },
  planStatLabel: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 10,
    marginTop: 3,
  },
  ingredientList: {
    paddingVertical: 4,
  },
  ingredient: {
    minHeight: 58,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    paddingVertical: 7,
  },
  ingredientEmoji: {
    fontSize: 23,
  },
  ingredientName: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontSize: 13,
    fontWeight: '800',
  },
  ingredientNote: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 11,
    marginTop: 3,
  },
  reasonRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: spacing.sm,
    marginTop: spacing.md,
  },
  reasonText: {
    flex: 1,
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
    lineHeight: 19,
  },
  marginTop: {
    marginTop: spacing.lg,
  },
});
