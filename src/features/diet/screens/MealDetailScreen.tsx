import React, { useCallback, useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { BadgeCheck, RefreshCw } from 'lucide-react-native';

import type { DietStackParamList } from '../../../navigation/types';
import { PageShell } from '../../../navigation/components/PageShell';
import { getErrorMessage } from '../../../shared/api/client';
import { AppButton, EmptyState, GlassCard, SectionTitle, Tag, useToast } from '../../../shared/components';
import { colors, fonts } from '../../../shared/theme/tokens';
import { NutrientList, NutrientMetricGrid } from '../components';
import { nutriApi } from '../api/nutriApi';
import type { Meal } from '../api/nutriTypes';
import { mealTypeLabels } from '../services/mealCorrection';
import { retryCaptureSession } from '../services/mealCapture';

type Props = NativeStackScreenProps<DietStackParamList, 'MealDetail'>;
function analysisStatusLabel(status: Meal['analysisStatus']): string {
  if (status === 'completed') return '分析完成';
  if (status === 'analysing') return 'AI 分析中';
  if (status === 'failed') return '分析失败';
  return '等待 AI 分析';
}
export function MealDetailScreen({ navigation, route }: Props) {
  const { show } = useToast(); const [meal, setMeal] = useState<Meal | null>(null); const [retrying, setRetrying] = useState(false);
  const load = useCallback(async () => { try { setMeal(await nutriApi.getMeal(route.params.mealId)); } catch (error) { show(getErrorMessage(error), 'error'); } }, [route.params.mealId, show]);
  useEffect(() => { load(); }, [load]);
  useEffect(() => { if (!meal || !['queued', 'analysing'].includes(meal.analysisStatus)) return undefined; const timer = setInterval(() => { load(); }, 8000); return () => clearInterval(timer); }, [load, meal]);
  const retry = useCallback(async () => { if (!meal || retrying) return; setRetrying(true); try { const result = await retryCaptureSession(meal.captureSessionId); setMeal(result.meal); show('已重新提交 AI 分析。', 'success'); } catch (error) { show(getErrorMessage(error), 'error'); } finally { setRetrying(false); } }, [meal, retrying, show]);
  if (!meal) return <PageShell pageId="mealDetail" onBack={() => navigation.goBack()}><EmptyState title="正在加载本餐报告" description="请稍候…" /></PageShell>;
  return <PageShell pageId="mealDetail" onBack={() => navigation.goBack()}><GlassCard><View style={styles.lead}><View><Text style={styles.title}>{mealTypeLabels[meal.mealType]}</Text><Text style={styles.meta}>{new Date(meal.consumedAt).toLocaleString()} · {meal.localDate}</Text></View><Tag label={analysisStatusLabel(meal.analysisStatus)} tone={meal.analysisStatus === 'failed' ? 'amber' : 'green'} /></View>{meal.notes ? <Text style={styles.note}>{meal.notes}</Text> : null}{meal.analysisStatus !== 'completed' ? <Text style={styles.pending}>餐食已经入库，营养数据将由 AI 异步补充。你可以先修正餐次、时间和备注。</Text> : null}{meal.analysisStatus === 'failed' ? <AppButton label={retrying ? '正在重新提交…' : '重新提交 AI 分析'} icon={<RefreshCw color="#FFFFFF" size={17} />} disabled={retrying} onPress={retry} /> : null}</GlassCard><GlassCard><SectionTitle title="整餐营养" detail="基于当前条目自动汇总" />{meal.nutrients.length ? <NutrientMetricGrid nutrients={meal.nutrients} /> : <EmptyState title="营养数据尚未生成" description="AI 完成分析后，这里会显示完整营养素。" />}</GlassCard><GlassCard><SectionTitle title="全部营养素" detail="可随营养字典扩展" />{meal.nutrients.length ? <NutrientList nutrients={meal.nutrients} /> : <Text style={styles.pending}>当前没有可展示的营养值。</Text>}</GlassCard><GlassCard><SectionTitle title="识别到的餐食项" />{meal.items.length ? meal.items.map(item => <View key={item.itemId} style={styles.item}><View style={styles.itemHead}><Text style={styles.itemName}>{item.displayName}</Text><View style={styles.tags}>{item.confidence !== null ? <Tag label={`置信度 ${Math.round(item.confidence * 100)}%`} tone="green" /> : null}{item.userCorrected ? <Tag label="已人工修正" tone="amber" /> : null}</View></View><Text style={styles.itemMeta}>{item.estimatedWeightG ? `估算 ${item.estimatedWeightG} g` : '未估算重量'} · {item.dataSource === 'ai' ? 'AI 数据' : '人工数据'}</Text><NutrientList nutrients={item.nutrients} /></View>) : <Text style={styles.pending}>AI 还没有返回餐食项。</Text>}</GlassCard><AppButton label="修正本餐" icon={<BadgeCheck color="#FFFFFF" size={17} />} onPress={() => navigation.navigate('MealCorrection', { mealId: meal.mealId })} /></PageShell>;
}
const styles = StyleSheet.create({ lead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' }, title: { color: colors.ink, fontFamily: fonts.body, fontSize: 21, fontWeight: '800' }, meta: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, marginTop: 5 }, note: { color: colors.muted, fontFamily: fonts.body, fontSize: 14, lineHeight: 20, marginTop: 13 }, pending: { color: colors.muted, fontFamily: fonts.body, fontSize: 13, lineHeight: 20, marginTop: 12 }, item: { gap: 9, paddingVertical: 13, borderBottomColor: colors.line, borderBottomWidth: StyleSheet.hairlineWidth }, itemHead: { flexDirection: 'row', justifyContent: 'space-between', gap: 8 }, itemName: { flex: 1, color: colors.ink, fontFamily: fonts.body, fontSize: 16, fontWeight: '800' }, tags: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'flex-end', gap: 5 }, itemMeta: { color: colors.muted, fontFamily: fonts.body, fontSize: 12 } });
