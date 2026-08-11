import React, { memo, useCallback, useMemo, useState } from 'react';
import { Alert, FlatList, InteractionManager, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ChevronRight, Ruler, Scale, ShieldAlert, Stethoscope, Target, Trash2, Utensils } from 'lucide-react-native';

import type { ProfileStackParamList } from '../../../navigation/types';
import { getErrorMessage } from '../../../shared/api/client';
import { PressableScale } from '../../../shared/animation/PressableScale';
import { AppButton, AppScreen, EmptyState, GlassCard, ScreenHeader, SectionTitle, inputStyle } from '../../../shared/components/ui';
import { colors, fonts, radii, spacing } from '../../../shared/theme/tokens';
import type { Allergy, BodyMeasurement, DietaryRestriction, HealthGoal, MedicalCondition } from '../../../shared/types/api';
import { useToast } from '../../../shared/components/Toast';
import { healthApi } from '../api/healthApi';
import {
  getCachedHealthRecords,
  getHealthRecords,
  invalidateHealthRecords,
} from '../services/healthRecordsCache';

type HealthProps = NativeStackScreenProps<ProfileStackParamList, 'HealthRecords'>;
type FormProps = NativeStackScreenProps<ProfileStackParamList, 'HealthRecordForm'>;
type Kind = FormProps['route']['params']['kind'];

type HealthData = {
  measurements: BodyMeasurement[];
  goals: HealthGoal[];
  allergies: Allergy[];
  conditions: MedicalCondition[];
  restrictions: DietaryRestriction[];
};

const emptyData: HealthData = { measurements: [], goals: [], allergies: [], conditions: [], restrictions: [] };
const kindTitle: Record<Kind, string> = { measurement: '身体测量', goal: '健康目标', allergy: '过敏记录', condition: '疾病记录', restriction: '饮食限制' };

function formatDate(value?: string | null): string {
  return value ? value.slice(0, 10) : '未填写';
}

function customCode(): string {
  return `custom-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

const RecordSection = memo(function ({ icon, title, detail, count, onPress }: { icon: React.ReactNode; title: string; detail: string; count: number; onPress: () => void }) {
  return <PressableScale accessibilityRole="button" onPress={onPress} style={styles.recordSection}>
    <View style={styles.recordIcon}>{icon}</View>
    <View style={styles.recordCopy}><Text style={styles.recordTitle}>{title}</Text><Text style={styles.recordDetail}>{detail}</Text></View>
    <View style={styles.count}><Text style={styles.countText}>{count} 条</Text></View>
    <ChevronRight color={colors.muted} size={18} />
  </PressableScale>;
});

export function HealthRecordsScreen({ navigation, route }: HealthProps) {
  const { show } = useToast();
  const [data, setData] = useState<HealthData>(emptyData);
  const [loading, setLoading] = useState(true);
  const load = useCallback(async (force = false) => {
    const cached = !force ? getCachedHealthRecords() : null;
    if (cached) {
      setData(cached);
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      setData(await getHealthRecords(force));
    } catch (error) {
      show(getErrorMessage(error), 'error');
    } finally {
      setLoading(false);
    }
  }, [show]);

  useFocusEffect(useCallback(() => {
    const task = InteractionManager.runAfterInteractions(() => {
      load().catch(() => undefined);
    });
    return () => task.cancel();
  }, [load]));
  const open = (kind: Kind) => navigation.navigate('HealthRecordForm', { kind });
  return <AppScreen header={<ScreenHeader title="健康档案" subtitle="集中管理你的健康资料" onBack={() => navigation.goBack()} />}>
    <GlassCard elevated={false} variant="soft" style={styles.overview}>
      <Text style={styles.overviewTitle}>{route.params?.onboarding ? '基础档案已保存' : '健康资料'} </Text>
      <Text style={styles.overviewText}>{route.params?.onboarding ? '接下来可补充身体数据与健康记录，也可以稍后再填。' : '每一项都可以随时新增、修改或删除。'}</Text>
      {route.params?.onboarding ? <AppButton label="暂不添加，进入我的页面" variant="secondary" onPress={() => navigation.replace('ProfileMain')} /> : null}
    </GlassCard>
    <SectionTitle title="基础与测量" />
    <GlassCard elevated={false} variant="soft" style={styles.sectionCard}>
      <RecordSection icon={<Ruler color={colors.blue} size={19} />} title="基础档案" detail="生日、身高、活动与饮水目标" count={1} onPress={() => navigation.navigate('EditProfile')} />
      <RecordSection icon={<Scale color={colors.blue} size={19} />} title="身体测量" detail="体重、体脂、围度、血压与心率" count={data.measurements.length} onPress={() => open('measurement')} />
    </GlassCard>
    <SectionTitle title="健康计划与提醒" />
    <GlassCard elevated={false} variant="soft" style={styles.sectionCard}>
      <RecordSection icon={<Target color={colors.green} size={19} />} title="健康目标" detail="体重、体脂与改善方向" count={data.goals.length} onPress={() => open('goal')} />
      <RecordSection icon={<ShieldAlert color={colors.amber} size={19} />} title="过敏记录" detail="过敏原、严重程度与反应" count={data.allergies.length} onPress={() => open('allergy')} />
      <RecordSection icon={<Stethoscope color={colors.red} size={19} />} title="疾病记录" detail="诊断状态、日期与备注" count={data.conditions.length} onPress={() => open('condition')} />
      <RecordSection icon={<Utensils color={colors.violet} size={19} />} title="饮食限制" detail="限制类别、生效日期与备注" count={data.restrictions.length} onPress={() => open('restriction')} />
    </GlassCard>
    {loading ? <Text style={styles.loading}>正在更新健康资料…</Text> : null}
  </AppScreen>;
}

const RecordRow = memo(function ({ title, detail, onPress }: { title: string; detail: string; onPress: () => void }) {
  return <PressableScale accessibilityRole="button" onPress={onPress} style={styles.recordRow}><View style={styles.recordRowCopy}><Text style={styles.rowTitle}>{title}</Text><Text numberOfLines={1} style={styles.rowDetail}>{detail}</Text></View><ChevronRight color={colors.muted} size={17} /></PressableScale>;
});

function Field({ label, value, onChange, placeholder, numeric = false, multiline = false }: { label: string; value: string; onChange: (value: string) => void; placeholder?: string; numeric?: boolean; multiline?: boolean }) {
  return <View style={styles.field}><Text style={styles.fieldLabel}>{label}</Text><TextInput accessibilityLabel={label} keyboardType={numeric ? 'decimal-pad' : 'default'} multiline={multiline} onChangeText={onChange} placeholder={placeholder} placeholderTextColor="#94A3B8" style={[inputStyle, multiline && styles.multiline]} value={value} /></View>;
}

function Choices({ label, value, values, onChange }: { label: string; value: string; values: Array<[string, string]>; onChange: (value: string) => void }) {
  return <View style={styles.field}><Text style={styles.fieldLabel}>{label}</Text><View style={styles.choices}>{values.map(([key, text]) => <Pressable key={key} onPress={() => onChange(key)} style={[styles.choice, value === key && styles.choiceActive]}><Text style={[styles.choiceText, value === key && styles.choiceTextActive]}>{text}</Text></Pressable>)}</View></View>;
}

function asNumber(value: string): number | undefined {
  const number = Number(value);
  return value.trim() && Number.isFinite(number) ? number : undefined;
}

function initialValues(kind: Kind, record?: BodyMeasurement | HealthGoal | Allergy | MedicalCondition | DietaryRestriction): Record<string, string> {
  if (!record) return kind === 'measurement' ? { measuredAt: new Date().toISOString(), heightCm: '', weightKg: '', bodyFatPercentage: '', waistCm: '', systolicBp: '', diastolicBp: '', restingHeartRate: '', notes: '' } : kind === 'goal' ? { goalType: 'health_improve', targetWeightKg: '', targetBodyFatPercentage: '', priority: '1', status: 'active', startedOn: new Date().toISOString().slice(0, 10), targetDate: '', notes: '' } : kind === 'allergy' ? { allergenName: '', severity: 'mild', diagnosisStatus: 'self_reported', recordedOn: '', notes: '' } : kind === 'condition' ? { conditionName: '', status: 'active', diagnosedOn: '', resolvedOn: '', notes: '' } : { restrictionName: '', category: 'preference', startsOn: '', endsOn: '', notes: '' };
  if (kind === 'measurement') { const item = record as BodyMeasurement; return { measuredAt: item.measuredAt, heightCm: String(item.heightCm ?? ''), weightKg: String(item.weightKg ?? ''), bodyFatPercentage: String(item.bodyFatPercentage ?? ''), waistCm: String(item.waistCm ?? ''), systolicBp: String(item.systolicBp ?? ''), diastolicBp: String(item.diastolicBp ?? ''), restingHeartRate: String(item.restingHeartRate ?? ''), notes: item.notes ?? '' }; }
  if (kind === 'goal') { const item = record as HealthGoal; return { goalType: item.goalType, targetWeightKg: String(item.targetWeightKg ?? ''), targetBodyFatPercentage: String(item.targetBodyFatPercentage ?? ''), priority: String(item.priority), status: item.status, startedOn: item.startedOn, targetDate: item.targetDate ?? '', notes: item.notes ?? '' }; }
  if (kind === 'allergy') { const item = record as Allergy; return { allergenName: item.allergenName, severity: item.severity ?? 'mild', diagnosisStatus: item.diagnosisStatus, recordedOn: item.recordedOn ?? '', notes: item.notes ?? '' }; }
  if (kind === 'condition') { const item = record as MedicalCondition; return { conditionName: item.conditionName, status: item.status, diagnosedOn: item.diagnosedOn ?? '', resolvedOn: item.resolvedOn ?? '', notes: item.notes ?? '' }; }
  const item = record as DietaryRestriction; return { restrictionName: item.restrictionName, category: item.category, startsOn: item.startsOn ?? '', endsOn: item.endsOn ?? '', notes: item.notes ?? '' };
}

export function HealthRecordFormScreen({ navigation, route }: FormProps) {
  const { show } = useToast();
  const { kind, id } = route.params;
  const [records, setRecords] = useState<Array<BodyMeasurement | HealthGoal | Allergy | MedicalCondition | DietaryRestriction>>([]);
  const [values, setValues] = useState<Record<string, string>>(initialValues(kind));
  const [saving, setSaving] = useState(false);
  const idField = kind === 'measurement' ? 'measurementId' : kind === 'goal' ? 'goalId' : kind === 'allergy' ? 'allergyId' : kind === 'condition' ? 'conditionId' : 'restrictionId';
  const current = useMemo(() => records.find(item => String((item as unknown as Record<string, unknown>)[idField]) === id), [id, idField, records]);
  const set = (key: string) => (value: string) => setValues(previous => ({ ...previous, [key]: value }));

  const loadRecords = useCallback(() => {
    const list = kind === 'measurement' ? healthApi.bodyMeasurements.list() : kind === 'goal' ? healthApi.healthGoals.list() : kind === 'allergy' ? healthApi.allergies.list() : kind === 'condition' ? healthApi.medicalConditions.list() : healthApi.dietaryRestrictions.list();
    list.then(result => { setRecords(result); const found = result.find(item => String((item as unknown as Record<string, unknown>)[idField]) === id); if (found) setValues(initialValues(kind, found)); }).catch(error => show(getErrorMessage(error), 'error'));
  }, [id, idField, kind, show]);

  useFocusEffect(useCallback(() => { loadRecords(); }, [loadRecords]));

  const save = async () => {
    if ((kind === 'allergy' && !values.allergenName.trim()) || (kind === 'condition' && !values.conditionName.trim()) || (kind === 'restriction' && !values.restrictionName.trim())) { show('请填写记录名称', 'error'); return; }
    if (kind === 'measurement' && !['heightCm', 'weightKg', 'bodyFatPercentage', 'waistCm', 'systolicBp', 'diastolicBp', 'restingHeartRate'].some(key => values[key].trim())) { show('请至少填写一个身体指标', 'error'); return; }
    setSaving(true);
    try {
      if (kind === 'measurement') { const payload = { measuredAt: values.measuredAt || undefined, heightCm: asNumber(values.heightCm), weightKg: asNumber(values.weightKg), bodyFatPercentage: asNumber(values.bodyFatPercentage), waistCm: asNumber(values.waistCm), systolicBp: asNumber(values.systolicBp), diastolicBp: asNumber(values.diastolicBp), restingHeartRate: asNumber(values.restingHeartRate), source: 'manual' as const, notes: values.notes.trim() || undefined }; id ? await healthApi.bodyMeasurements.update(id, payload) : await healthApi.bodyMeasurements.create(payload); }
      if (kind === 'goal') { const payload = { goalType: values.goalType as HealthGoal['goalType'], targetWeightKg: asNumber(values.targetWeightKg), targetBodyFatPercentage: asNumber(values.targetBodyFatPercentage), priority: asNumber(values.priority), status: values.status as HealthGoal['status'], startedOn: values.startedOn || undefined, targetDate: values.targetDate || undefined, notes: values.notes.trim() || undefined }; id ? await healthApi.healthGoals.update(id, payload) : await healthApi.healthGoals.create(payload); }
      if (kind === 'allergy') { const payload = { allergenCode: current && 'allergenCode' in current ? current.allergenCode : customCode(), allergenName: values.allergenName.trim(), severity: values.severity as NonNullable<Allergy['severity']>, diagnosisStatus: values.diagnosisStatus as Allergy['diagnosisStatus'], recordedOn: values.recordedOn || undefined, active: true, notes: values.notes.trim() || undefined }; id ? await healthApi.allergies.update(id, payload) : await healthApi.allergies.create(payload); }
      if (kind === 'condition') { const payload = { conditionCode: current && 'conditionCode' in current ? current.conditionCode : customCode(), conditionName: values.conditionName.trim(), status: values.status as MedicalCondition['status'], diagnosedOn: values.diagnosedOn || undefined, resolvedOn: values.resolvedOn || undefined, source: 'self_reported' as const, notes: values.notes.trim() || undefined }; id ? await healthApi.medicalConditions.update(id, payload) : await healthApi.medicalConditions.create(payload); }
      if (kind === 'restriction') { const payload = { restrictionCode: current && 'restrictionCode' in current ? current.restrictionCode : customCode(), restrictionName: values.restrictionName.trim(), category: values.category as DietaryRestriction['category'], source: 'self_reported' as const, active: true, startsOn: values.startsOn || undefined, endsOn: values.endsOn || undefined, notes: values.notes.trim() || undefined }; id ? await healthApi.dietaryRestrictions.update(id, payload) : await healthApi.dietaryRestrictions.create(payload); }
      invalidateHealthRecords();
      show(`${kindTitle[kind]}已保存`, 'success'); navigation.goBack();
    } catch (error) { show(getErrorMessage(error), 'error'); } finally { setSaving(false); }
  };
  const remove = () => Alert.alert('删除记录', '删除后无法恢复，确定继续吗？', [{ text: '取消', style: 'cancel' }, { text: '删除', style: 'destructive', onPress: async () => { try { if (kind === 'measurement') await healthApi.bodyMeasurements.remove(id!); if (kind === 'goal') await healthApi.healthGoals.remove(id!); if (kind === 'allergy') await healthApi.allergies.remove(id!); if (kind === 'condition') await healthApi.medicalConditions.remove(id!); if (kind === 'restriction') await healthApi.dietaryRestrictions.remove(id!); invalidateHealthRecords(); navigation.goBack(); } catch (error) { show(getErrorMessage(error), 'error'); } } }]);
  const openItem = useCallback((itemId: string) => {
    navigation.push('HealthRecordForm', { kind, id: itemId });
  }, [kind, navigation]);

  const keyExtractor = useCallback((item: typeof records[number]) => String((item as unknown as Record<string, unknown>)[idField]), [idField]);

  const renderRecord = useCallback(({ item }: { item: typeof records[number] }) => {
    const itemId = String((item as unknown as Record<string, unknown>)[idField]);
    const title = kind === 'measurement' ? `${(item as BodyMeasurement).weightKg ?? '—'} kg · ${formatDate((item as BodyMeasurement).measuredAt)}` : kind === 'goal' ? (item as HealthGoal).goalType : kind === 'allergy' ? (item as Allergy).allergenName : kind === 'condition' ? (item as MedicalCondition).conditionName : (item as DietaryRestriction).restrictionName;
    return <GlassCard elevated={false} variant="soft" style={styles.recordListCard}><RecordRow title={title} detail="点击查看或修改" onPress={() => openItem(itemId)} /></GlassCard>;
  }, [idField, kind, openItem]);
  const fields = kind === 'measurement' ? <><Field label="测量时间" value={values.measuredAt} onChange={set('measuredAt')} placeholder="ISO 日期时间" /><Field label="体重 (kg)" value={values.weightKg} onChange={set('weightKg')} numeric /><Field label="体脂率 (%)" value={values.bodyFatPercentage} onChange={set('bodyFatPercentage')} numeric /><Field label="腰围 (cm)" value={values.waistCm} onChange={set('waistCm')} numeric /><Field label="本次身高 (cm)" value={values.heightCm} onChange={set('heightCm')} numeric /><Field label="收缩压 (mmHg)" value={values.systolicBp} onChange={set('systolicBp')} numeric /><Field label="舒张压 (mmHg)" value={values.diastolicBp} onChange={set('diastolicBp')} numeric /><Field label="静息心率 (bpm)" value={values.restingHeartRate} onChange={set('restingHeartRate')} numeric /><Field label="备注" value={values.notes} onChange={set('notes')} multiline /></> : kind === 'goal' ? <><Choices label="目标方向" value={values.goalType} onChange={set('goalType')} values={[["weight_loss", "减重"], ["muscle_gain", "增肌"], ["maintain", "保持"], ["health_improve", "改善健康"]]} /><Field label="目标体重 (kg)" value={values.targetWeightKg} onChange={set('targetWeightKg')} numeric /><Field label="目标体脂率 (%)" value={values.targetBodyFatPercentage} onChange={set('targetBodyFatPercentage')} numeric /><Field label="优先级 (1–10)" value={values.priority} onChange={set('priority')} numeric /><Field label="开始日期" value={values.startedOn} onChange={set('startedOn')} placeholder="YYYY-MM-DD" /><Field label="目标日期" value={values.targetDate} onChange={set('targetDate')} placeholder="YYYY-MM-DD（选填）" /><Field label="备注" value={values.notes} onChange={set('notes')} multiline /></> : kind === 'allergy' ? <><Field label="过敏原名称" value={values.allergenName} onChange={set('allergenName')} placeholder="例如：花生" /><Choices label="严重程度" value={values.severity} onChange={set('severity')} values={[["mild", "轻微"], ["moderate", "中等"], ["severe", "严重"], ["life_threatening", "危及生命"]]} /><Choices label="确认状态" value={values.diagnosisStatus} onChange={set('diagnosisStatus')} values={[["self_reported", "自行记录"], ["suspected", "疑似"], ["confirmed", "已确认"]]} /><Field label="记录日期" value={values.recordedOn} onChange={set('recordedOn')} placeholder="YYYY-MM-DD（选填）" /><Field label="备注" value={values.notes} onChange={set('notes')} multiline /></> : kind === 'condition' ? <><Field label="疾病名称" value={values.conditionName} onChange={set('conditionName')} /><Choices label="当前状态" value={values.status} onChange={set('status')} values={[["active", "进行中"], ["remission", "缓解"], ["resolved", "已解决"]]} /><Field label="诊断日期" value={values.diagnosedOn} onChange={set('diagnosedOn')} placeholder="YYYY-MM-DD（选填）" /><Field label="结束日期" value={values.resolvedOn} onChange={set('resolvedOn')} placeholder="YYYY-MM-DD（选填）" /><Field label="备注" value={values.notes} onChange={set('notes')} multiline /></> : <><Field label="限制名称" value={values.restrictionName} onChange={set('restrictionName')} placeholder="例如：不吃牛肉" /><Choices label="限制类别" value={values.category} onChange={set('category')} values={[["medical", "医疗"], ["religious", "宗教"], ["lifestyle", "生活方式"], ["preference", "个人偏好"]]} /><Field label="生效日期" value={values.startsOn} onChange={set('startsOn')} placeholder="YYYY-MM-DD（选填）" /><Field label="结束日期" value={values.endsOn} onChange={set('endsOn')} placeholder="YYYY-MM-DD（选填）" /><Field label="备注" value={values.notes} onChange={set('notes')} multiline /></>;
  if (!id && !route.params.create) return <AppScreen scroll={false} contentStyle={styles.listScreen} header={<ScreenHeader title={kindTitle[kind]} subtitle="查看、修改或添加健康记录" onBack={() => navigation.goBack()} />}>
    <FlatList
      data={records}
      contentContainerStyle={styles.listContent}
      keyExtractor={keyExtractor}
      renderItem={renderRecord}
      removeClippedSubviews={Platform.OS === 'android'}
      initialNumToRender={8}
      windowSize={7}
      maxToRenderPerBatch={10}
      ListHeaderComponent={<SectionTitle title="已有记录" />}
      ListEmptyComponent={<EmptyState title="还没有记录" description="从第一条开始，逐步完善健康档案。" />}
      ListFooterComponent={<AppButton label={`添加${kindTitle[kind]}`} onPress={() => navigation.replace('HealthRecordForm', { kind, create: true })} />}
      showsVerticalScrollIndicator={false}
    />
  </AppScreen>;
  return <AppScreen header={<ScreenHeader title={id ? `编辑${kindTitle[kind]}` : `添加${kindTitle[kind]}`} subtitle={id ? '修改后会同步更新健康档案' : '按需填写，之后也可随时编辑'} onBack={() => navigation.goBack()} />}>
    <GlassCard elevated={false} variant="soft" style={styles.formCard}>{fields}<AppButton label={id ? '保存修改' : `添加${kindTitle[kind]}`} loading={saving} onPress={save} />{id ? <Pressable accessibilityRole="button" onPress={remove} style={styles.delete}><Trash2 color={colors.red} size={17} /><Text style={styles.deleteText}>删除这条记录</Text></Pressable> : null}</GlassCard>
  </AppScreen>;
}

const styles = StyleSheet.create({
  overview: { gap: spacing.sm }, overviewTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 18, fontWeight: '800' }, overviewText: { color: colors.muted, fontFamily: fonts.body, fontSize: 13, lineHeight: 19 }, sectionCard: { paddingVertical: 0 }, recordSection: { minHeight: 70, flexDirection: 'row', alignItems: 'center', gap: spacing.sm, paddingVertical: spacing.sm, borderBottomColor: colors.line, borderBottomWidth: StyleSheet.hairlineWidth }, recordIcon: { width: 34, height: 34, borderRadius: 12, alignItems: 'center', justifyContent: 'center', backgroundColor: '#F1F7FD' }, recordCopy: { flex: 1 }, recordTitle: { color: colors.ink, fontFamily: fonts.body, fontSize: 14, fontWeight: '800' }, recordDetail: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, marginTop: 3 }, count: { minWidth: 38, alignItems: 'flex-end' }, countText: { color: colors.blue, fontFamily: fonts.body, fontSize: 12, fontWeight: '800' }, loading: { color: colors.muted, fontFamily: fonts.body, textAlign: 'center', fontSize: 12 }, recordRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, paddingVertical: spacing.md }, recordRowCopy: { flex: 1 }, rowTitle: { color: colors.ink, fontFamily: fonts.body, fontSize: 14, fontWeight: '800' }, rowDetail: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, marginTop: 3 }, formCard: { gap: spacing.md }, listScreen: { flex: 1 }, listContent: { paddingHorizontal: spacing.lg, paddingBottom: 104, gap: spacing.sm }, recordListCard: { paddingVertical: 0 }, field: { gap: 7 }, fieldLabel: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '700' }, multiline: { minHeight: 88, textAlignVertical: 'top', paddingTop: spacing.md }, choices: { flexDirection: 'row', flexWrap: 'wrap', gap: 7 }, choice: { backgroundColor: '#F1F5F9', borderRadius: radii.pill, paddingHorizontal: 12, paddingVertical: 8 }, choiceActive: { backgroundColor: colors.blueSoft, borderWidth: 1, borderColor: '#B9DBFA' }, choiceText: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, fontWeight: '700' }, choiceTextActive: { color: colors.blue }, delete: { alignSelf: 'center', alignItems: 'center', flexDirection: 'row', gap: 6, padding: spacing.sm }, deleteText: { color: colors.red, fontFamily: fonts.body, fontSize: 13, fontWeight: '800' },
});
