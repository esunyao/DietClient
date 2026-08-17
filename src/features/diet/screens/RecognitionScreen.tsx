import React, { useCallback, useEffect, useState } from 'react';
import { Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { launchCamera, launchImageLibrary, type Asset } from 'react-native-image-picker';
import { Camera, List, RefreshCw, Send, X } from 'lucide-react-native';

import type { DietStackParamList } from '../../../navigation/types';
import { PageShell } from '../../../navigation/components/PageShell';
import { getErrorMessage } from '../../../shared/api/client';
import { AppButton, EmptyState, GlassCard, SectionTitle, Tag, inputStyle, useToast } from '../../../shared/components';
import { colors, fonts } from '../../../shared/theme/tokens';
import { CaptureImageGrid, MealHistoryRow, MealTypeSegmentedControl, NutrientMetricGrid } from '../components';
import { nutriApi } from '../api/nutriApi';
import type { CapturePolicy, CaptureSession, Meal, MealHistoryItem, MealType } from '../api/nutriTypes';
import { createCaptureSession, loadRecognitionBootstrap, prepareCaptureImageFile, recentMealQuery, resolveDeviceTimezone, retryCaptureSession, submitCaptureSession, uploadAndConfirmCaptureImage, type CaptureImageFile } from '../services/mealCapture';

type Props = NativeStackScreenProps<DietStackParamList, 'Recognition'>;
type Mode = 'personal' | 'canteen';
type LoadState = 'loading' | 'ready' | 'error';

const terminalStatuses = new Set(['completed', 'expired', 'cancelled']);
const lockedStatuses = new Set(['ready_for_analysis', 'analysing', 'completed', 'failed', 'expired', 'cancelled']);

function defaultMealType(date = new Date()): MealType {
  const hour = date.getHours();
  if (hour >= 5 && hour < 11) return 'breakfast';
  if (hour >= 11 && hour < 15) return 'lunch';
  if (hour >= 17 && hour < 22) return 'dinner';
  return 'snack';
}

async function selectAssets(camera: boolean, remaining: number): Promise<Asset[]> {
  const result = camera
    ? await launchCamera({ mediaType: 'photo', quality: 0.9, saveToPhotos: false, assetRepresentationMode: 'compatible' })
    : await launchImageLibrary({ mediaType: 'photo', quality: 0.9, selectionLimit: remaining, assetRepresentationMode: 'compatible' });
  if (result.errorMessage) throw new Error(result.errorMessage);
  return result.assets ?? [];
}

function isWorking(status?: string): boolean {
  return status === 'ready_for_analysis' || status === 'analysing';
}

function statusLabel(status?: string): string {
  if (status === 'failed') return '识别失败';
  if (status === 'ready_for_analysis') return '等待 AI 分析';
  if (status === 'analysing') return 'AI 分析中';
  if (status === 'created' || status === 'uploading') return '待提交';
  if (status === 'completed') return '分析完成';
  return status ?? '待提交';
}

export function RecognitionScreen({ navigation }: Props) {
  const { show } = useToast();
  const [mode, setMode] = useState<Mode>('personal');
  const [policy, setPolicy] = useState<CapturePolicy | null>(null);
  const [policyState, setPolicyState] = useState<LoadState>('loading');
  const [session, setSession] = useState<CaptureSession | null>(null);
  const [submittedMeal, setSubmittedMeal] = useState<Meal | null>(null);
  const [files, setFiles] = useState<CaptureImageFile[]>([]);
  const [progress, setProgress] = useState<Record<string, number>>({});
  const [uploading, setUploading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [mealType, setMealType] = useState<MealType>(() => defaultMealType());
  const [notes, setNotes] = useState('');
  const [recent, setRecent] = useState<MealHistoryItem[]>([]);
  const [historyState, setHistoryState] = useState<LoadState>('loading');

  const refreshRecent = useCallback(async () => {
    try {
      const result = await nutriApi.listMeals({ ...recentMealQuery(), pageSize: 6 });
      setRecent(result.items);
      setHistoryState('ready');
    } catch {
      setHistoryState('error');
    }
  }, []);

  const load = useCallback(async () => {
    setPolicy(null);
    setPolicyState('loading');
    setHistoryState('loading');
    const result = await loadRecognitionBootstrap();
    if (result.policy.status === 'fulfilled') {
      setPolicy(result.policy.value);
      setPolicyState('ready');
    } else {
      setPolicyState('error');
      show(`无法读取上传规则：${getErrorMessage(result.policy.reason)}`, 'error');
    }
    if (result.session.status === 'fulfilled') setSession(result.session.value);
    if (result.history.status === 'fulfilled') {
      setRecent(result.history.value.items);
      setHistoryState('ready');
    } else {
      setHistoryState('error');
    }
  }, [show]);

  useEffect(() => { load(); }, [load]);
  useEffect(() => {
    if (!isWorking(session?.status)) return undefined;
    const timer = setInterval(() => {
      if (session) nutriApi.getCaptureSession(session.captureSessionId).then(setSession).catch(() => undefined);
    }, 10000);
    return () => clearInterval(timer);
  }, [session]);

  const addImages = useCallback(async (camera: boolean) => {
    if (!policy || policyState !== 'ready') return show('上传规则尚未准备完成，请稍后重试。', 'error');
    if (session && lockedStatuses.has(session.status)) return show('餐食已经提交，图片已锁定。', 'error');
    const limit = session?.maxImageCount ?? policy.maxImageCount;
    const confirmed = session?.images.filter(item => item.status === 'confirmed').length ?? 0;
    const remaining = limit - confirmed;
    if (remaining <= 0) return show(`本次识别最多 ${limit} 张图片。`, 'error');
    try {
      const assets = await selectAssets(camera, remaining);
      const prepared: CaptureImageFile[] = [];
      for (const asset of assets.slice(0, remaining)) {
        const file = await prepareCaptureImageFile(asset);
        if (!policy.allowedContentTypes.includes(file.contentType)) throw new Error('该图片格式不在服务端允许范围内。');
        if (file.byteSize > policy.maxFileSizeBytes) throw new Error('图片大小超过服务端限制。');
        prepared.push(file);
      }
      if (!prepared.length) return;
      setUploading(true);
      let active = session ?? await createCaptureSession(resolveDeviceTimezone());
      setSession(active);
      for (const file of prepared) {
        setFiles(current => [...current, file]);
        active = await uploadAndConfirmCaptureImage(active.captureSessionId, file, value => setProgress(current => ({ ...current, [file.uri]: value })));
        setSession(active);
        setProgress(current => ({ ...current, [file.uri]: 100 }));
      }
      show('图片已确认，请选择餐次后提交。', 'success');
    } catch (error) {
      show(getErrorMessage(error), 'error');
    } finally {
      setUploading(false);
    }
  }, [policy, policyState, session, show]);

  const submit = useCallback(async () => {
    if (!session) return show('请先拍摄或选择至少一张餐盘图片。', 'error');
    if (!session.images.some(item => item.status === 'confirmed')) return show('请先确认至少一张图片。', 'error');
    if (submitting) return;
    setSubmitting(true);
    try {
      const result = await submitCaptureSession(session.captureSessionId, { mealType, notes: notes.trim() || null });
      setSession(result.captureSession);
      setSubmittedMeal(result.meal);
      await refreshRecent();
      show('餐食已入库，正在等待 AI 分析。', 'success');
    } catch (error) {
      show(getErrorMessage(error), 'error');
    } finally {
      setSubmitting(false);
    }
  }, [mealType, notes, refreshRecent, session, show, submitting]);

  const retry = useCallback(async () => {
    if (!session) return;
    try {
      const result = await retryCaptureSession(session.captureSessionId);
      setSession(result.captureSession);
      setSubmittedMeal(result.meal);
      await refreshRecent();
      show('已重新排队等待 AI 分析。', 'success');
    } catch (error) {
      show(getErrorMessage(error), 'error');
    }
  }, [refreshRecent, session, show]);

  const cancel = useCallback(async () => {
    if (!session) return;
    try {
      await nutriApi.cancelCaptureSession(session.captureSessionId);
      setSession(null);
      setSubmittedMeal(null);
      setFiles([]);
      setProgress({});
      show('已取消本次采集。', 'success');
    } catch (error) {
      show(getErrorMessage(error), 'error');
    }
  }, [session, show]);

  const confirmedCount = session?.images.filter(item => item.status === 'confirmed').length ?? 0;
  const historyAction = <Pressable accessibilityLabel="查看饮食记录" onPress={() => navigation.navigate('MealHistory')} style={recognitionMetaStyles.historyAction}><List color={colors.blue} size={17} /><Text style={recognitionMetaStyles.historyActionText}>历史</Text></Pressable>;
  if (mode === 'canteen') return <PageShell pageId="recognition" action={historyAction}><ModeSwitch mode={mode} onChange={setMode} /><CanteenDemo /><RecentHistory meals={recent} state={historyState} onRetry={load} onAll={() => navigation.navigate('MealHistory')} onOpen={mealId => navigation.navigate('MealDetail', { mealId })} /></PageShell>;

  const canEditCapture = session ? !lockedStatuses.has(session.status) : true;
  return <PageShell pageId="recognition" action={historyAction}>
    <ModeSwitch mode={mode} onChange={setMode} />
    <GlassCard style={styles.captureCard}>
      <View style={styles.scanFrame}><Camera color={colors.blue} size={35} /><View style={styles.scanLine} /></View>
      <Text style={styles.captureTitle}>把餐盘放进取景框</Text>
      <Text style={styles.captureText}>拍一张整体餐盘照片即可。AI 会在后台识别菜品、份量与营养，不需要先填写菜名或克数。</Text>
      <View style={styles.actions}>
        {Platform.OS !== 'web' ? <AppButton label="拍照" variant="secondary" disabled={!policy || policyState !== 'ready' || uploading || !canEditCapture} onPress={() => addImages(true)} style={styles.action} /> : null}
        <AppButton label="从相册选择" variant="secondary" disabled={!policy || policyState !== 'ready' || uploading || !canEditCapture} onPress={() => addImages(false)} style={styles.action} />
      </View>
      <UploadPolicyHint policy={policy} state={policyState} onRetry={load} />
    </GlassCard>
    <CaptureImageGrid files={files} progress={progress} />
    {session && canEditCapture && confirmedCount > 0 ? <GlassCard style={styles.formCard}>
      <SectionTitle title="提交餐食" detail="提交后立即进入历史，AI 稍后补充营养数据" />
      <Text style={styles.label}>餐次</Text>
      <MealTypeSegmentedControl value={mealType} onChange={value => setMealType(value as MealType)} />
      <Text style={styles.label}>备注（选填）</Text>
      <TextInput accessibilityLabel="餐食备注" value={notes} onChangeText={setNotes} multiline style={[inputStyle, styles.textarea]} placeholder="例如：少油、在公司食堂" placeholderTextColor="#94A3B8" />
    </GlassCard> : null}
    {session ? <GlassCard style={styles.sessionCard}>
      <View style={styles.sessionHead}><View><Text style={styles.sessionTitle}>本次采集</Text><Text style={styles.sessionMeta}>已确认 {confirmedCount}/{session.maxImageCount} 张</Text></View><Tag label={statusLabel(session.status)} tone={session.status === 'failed' ? 'amber' : 'green'} /></View>
      {isWorking(session.status) ? <Text style={styles.queue}>餐食已入库，正在等待 AI 服务处理。你可以在历史记录中查看并修正餐次、时间和备注。</Text> : null}
      {submittedMeal && isWorking(session.status) ? <Text style={styles.queue}>记录编号：{submittedMeal.mealId}</Text> : null}
      <View style={styles.actions}>
        {session.status === 'failed' ? <AppButton label="重新提交" icon={<RefreshCw color="#FFFFFF" size={16} />} onPress={retry} style={styles.action} /> : <AppButton label={submitting ? '正在提交…' : '提交餐食'} icon={<Send color="#FFFFFF" size={16} />} disabled={submitting || uploading || confirmedCount === 0 || isWorking(session.status) || terminalStatuses.has(session.status)} onPress={submit} style={styles.action} />}
        <AppButton label="取消" variant="secondary" icon={<X color={colors.ink} size={16} />} disabled={session.status !== 'created' && session.status !== 'uploading'} onPress={cancel} style={styles.action} />
      </View>
    </GlassCard> : null}
    <RecentHistory meals={recent} state={historyState} onRetry={load} onAll={() => navigation.navigate('MealHistory')} onOpen={mealId => navigation.navigate('MealDetail', { mealId })} />
  </PageShell>;
}

function ModeSwitch({ mode, onChange }: { mode: Mode; onChange: (mode: Mode) => void }) { return <View style={styles.modeSwitch}>{(['personal', 'canteen'] as const).map(item => <Pressable key={item} onPress={() => onChange(item)} style={[styles.mode, mode === item && styles.modeActive]}><Text style={[styles.modeText, mode === item && styles.modeTextActive]}>{item === 'personal' ? '个人拍照' : '食堂菜单演示'}</Text></Pressable>)}</View>; }
function UploadPolicyHint({ policy, state, onRetry }: { policy: CapturePolicy | null; state: LoadState; onRetry: () => void }) { if (state === 'ready' && policy) return <Text style={styles.limit}>服务端规则：最多 {policy.maxImageCount} 张 · 单张 {(policy.maxFileSizeBytes / 1024 / 1024).toFixed(0)} MiB</Text>; if (state === 'error') return <Pressable accessibilityRole="button" onPress={onRetry} style={recognitionMetaStyles.retry}><Text style={recognitionMetaStyles.retryText}>上传规则读取失败，点击重新加载</Text></Pressable>; return <Text style={styles.limit}>正在读取服务端上传规则…</Text>; }
function CanteenDemo() { return <><GlassCard><Tag label="演示数据" tone="amber" /><Text style={styles.canteenTitle}>食堂今日午餐</Text><Text style={styles.captureText}>固定菜单与预置营养数据，仅用于展示，不调用 NutriMemo。</Text><View style={styles.menu}><Text style={styles.menuText}>香菇鸡腿饭 · 680 kcal</Text><Text style={styles.menuText}>清炒西兰花 · 蛋白质 32 g</Text><Text style={styles.menuText}>紫菜蛋花汤 · 钠 610 mg</Text></View></GlassCard><GlassCard><SectionTitle title="演示营养报告" detail="静态示例，不会写入历史" /><NutrientMetricGrid nutrients={[{ nutrientCode: 'ENERGY_KCAL', nutrientName: '能量', amount: 570, unit: 'kcal' }, { nutrientCode: 'PROTEIN', nutrientName: '蛋白质', amount: 42, unit: 'g' }, { nutrientCode: 'CARBOHYDRATE', nutrientName: '碳水', amount: 56, unit: 'g' }, { nutrientCode: 'FAT', nutrientName: '脂肪', amount: 18, unit: 'g' }]} /></GlassCard></>; }
function RecentHistory({ meals, state, onRetry, onAll, onOpen }: { meals: MealHistoryItem[]; state: LoadState; onRetry: () => void; onAll: () => void; onOpen: (id: string) => void }) { return <><SectionTitle title="最近饮食记录" detail="最多展示 6 条" action={<Pressable onPress={onAll}><Text style={styles.all}>查看全部记录</Text></Pressable>} />{state === 'error' ? <EmptyState title="历史记录暂时无法加载" description="不影响拍照识别；请检查网络后重新加载。" action={<AppButton label="重新加载" variant="secondary" onPress={onRetry} />} /> : meals.length ? <View style={styles.recent}>{meals.map(meal => <MealHistoryRow key={meal.mealId} meal={meal} onPress={() => onOpen(meal.mealId)} />)}</View> : <EmptyState title={state === 'loading' ? '正在加载历史记录' : '还没有饮食记录'} description={state === 'loading' ? '请稍候…' : '提交餐盘照片后，记录会立即出现在这里。'} />}</>; }

const recognitionMetaStyles = StyleSheet.create({ historyAction: { flexDirection: 'row', alignItems: 'center', gap: 4, paddingHorizontal: 2, paddingVertical: 2 }, historyActionText: { color: colors.blue, fontFamily: fonts.body, fontSize: 12, fontWeight: '800' }, retry: { paddingVertical: 4 }, retryText: { color: colors.blue, fontFamily: fonts.body, fontSize: 12, fontWeight: '800' } });
const styles = StyleSheet.create({ modeSwitch: { flexDirection: 'row', borderRadius: 18, backgroundColor: '#EAF1F7', padding: 4 }, mode: { flex: 1, paddingVertical: 9, alignItems: 'center', borderRadius: 14 }, modeActive: { backgroundColor: '#FFFFFF' }, modeText: { color: colors.muted, fontFamily: fonts.body, fontSize: 13, fontWeight: '800' }, modeTextActive: { color: colors.blue }, captureCard: { alignItems: 'center', gap: 11, padding: 18 }, scanFrame: { width: 142, height: 142, borderRadius: 28, borderWidth: 2, borderColor: 'rgba(0,113,227,0.27)', borderStyle: 'dashed', backgroundColor: '#F1F8FE', alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }, scanLine: { position: 'absolute', left: 17, right: 17, height: 2, backgroundColor: colors.green, top: 69 }, captureTitle: { color: colors.ink, fontFamily: fonts.body, fontSize: 19, fontWeight: '800' }, captureText: { color: colors.muted, fontFamily: fonts.body, fontSize: 13, textAlign: 'center', lineHeight: 19 }, actions: { width: '100%', flexDirection: 'row', gap: 8 }, action: { flex: 1 }, limit: { color: colors.muted, fontFamily: fonts.body, fontSize: 11 }, formCard: { gap: 11 }, label: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '700' }, textarea: { minHeight: 76, textAlignVertical: 'top' }, sessionCard: { gap: 13 }, sessionHead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }, sessionTitle: { color: colors.ink, fontFamily: fonts.body, fontSize: 16, fontWeight: '800' }, sessionMeta: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, marginTop: 3 }, queue: { color: colors.muted, fontFamily: fonts.body, fontSize: 13, lineHeight: 19 }, recent: { gap: 9 }, all: { color: colors.blue, fontFamily: fonts.body, fontWeight: '800', fontSize: 12 }, canteenTitle: { color: colors.ink, fontFamily: fonts.body, fontSize: 20, fontWeight: '800', marginTop: 10, marginBottom: 6 }, menu: { gap: 10, marginTop: 14 }, menuText: { color: colors.ink, fontFamily: fonts.body, fontSize: 14 } });
