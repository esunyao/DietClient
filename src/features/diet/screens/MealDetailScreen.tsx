import React, { useCallback, useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { BadgeCheck } from 'lucide-react-native';

import type { DietStackParamList } from '../../../navigation/types';
import { PageShell } from '../../../navigation/components/PageShell';
import { getErrorMessage } from '../../../shared/api/client';
import { AppButton, EmptyState, GlassCard, SectionTitle, Tag, useToast } from '../../../shared/components';
import { colors, fonts } from '../../../shared/theme/tokens';
import { NutrientList, NutrientMetricGrid } from '../components';
import { nutriApi } from '../api/nutriApi';
import type { Meal } from '../api/nutriTypes';
import { mealTypeLabels } from '../services/mealCorrection';

type Props = NativeStackScreenProps<DietStackParamList, 'MealDetail'>;
export function MealDetailScreen({ navigation, route }: Props) {
  const { show } = useToast(); const [meal, setMeal] = useState<Meal | null>(null);
  const load = useCallback(() => { nutriApi.getMeal(route.params.mealId).then(setMeal).catch(error => show(getErrorMessage(error), 'error')); }, [route.params.mealId, show]);
  useEffect(() => { load(); }, [load]);
  if (!meal) return <PageShell pageId="mealDetail" onBack={() => navigation.goBack()}><EmptyState title="正在加载本餐报告" description="请稍候…" /></PageShell>;
  return <PageShell pageId="mealDetail" onBack={() => navigation.goBack()}><GlassCard><View style={styles.lead}><View><Text style={styles.title}>{mealTypeLabels[meal.mealType]}</Text><Text style={styles.meta}>{new Date(meal.consumedAt).toLocaleString()} · {meal.localDate}</Text></View><Tag label={meal.captureSessionId ? 'AI 分析' : '人工记录'} tone="green" /></View>{meal.notes ? <Text style={styles.note}>{meal.notes}</Text> : null}</GlassCard><GlassCard><SectionTitle title="整餐营养" detail="基于当前条目自动汇总" /><NutrientMetricGrid nutrients={meal.nutrients} /></GlassCard><GlassCard><SectionTitle title="全部营养素" detail="可随营养字典扩展" /><NutrientList nutrients={meal.nutrients} /></GlassCard><GlassCard><SectionTitle title="识别到的餐食项" />{meal.items.map(item => <View key={item.itemId} style={styles.item}><View style={styles.itemHead}><Text style={styles.itemName}>{item.displayName}</Text><View style={styles.tags}>{item.confidence !== null ? <Tag label={`置信度 ${Math.round(item.confidence * 100)}%`} tone="green" /> : null}{item.userCorrected ? <Tag label="已人工修正" tone="amber" /> : null}</View></View><Text style={styles.itemMeta}>{item.estimatedWeightG ? `估算 ${item.estimatedWeightG} g` : '未估算重量'} · {item.dataSource === 'ai' ? 'AI 数据' : '人工数据'}</Text><NutrientList nutrients={item.nutrients} /></View>)}</GlassCard><AppButton label="修正本餐" icon={<BadgeCheck color="#FFFFFF" size={17} />} onPress={() => navigation.navigate('MealCorrection', { mealId: meal.mealId })} /></PageShell>;
}
const styles = StyleSheet.create({ lead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' }, title: { color: colors.ink, fontFamily: fonts.body, fontSize: 21, fontWeight: '800' }, meta: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, marginTop: 5 }, note: { color: colors.muted, fontFamily: fonts.body, fontSize: 14, lineHeight: 20, marginTop: 13 }, item: { gap: 9, paddingVertical: 13, borderBottomColor: colors.line, borderBottomWidth: StyleSheet.hairlineWidth }, itemHead: { flexDirection: 'row', justifyContent: 'space-between', gap: 8 }, itemName: { flex: 1, color: colors.ink, fontFamily: fonts.body, fontSize: 16, fontWeight: '800' }, tags: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'flex-end', gap: 5 }, itemMeta: { color: colors.muted, fontFamily: fonts.body, fontSize: 12 } });
