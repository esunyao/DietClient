import React, { useCallback, useEffect, useState } from 'react';
import { Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { launchCamera, launchImageLibrary, type Asset } from 'react-native-image-picker';
import { Camera, List, Send, X } from 'lucide-react-native';

import type { DietStackParamList } from '../../../navigation/types';
import { PageShell } from '../../../navigation/components/PageShell';
import { getErrorMessage } from '../../../shared/api/client';
import { AppButton, EmptyState, GlassCard, SectionTitle, Tag, inputStyle, useToast } from '../../../shared/components';
import { colors, fonts } from '../../../shared/theme/tokens';
import { CaptureDraftStrip, CaptureImageGrid, MealHistoryRow, MealTypeSegmentedControl, NutrientMetricGrid } from '../components';
import { nutriApi } from '../api/nutriApi';
import type { CaptureDraftSummary, CaptureImage, CapturePolicy, CaptureSession, MealHistoryItem, MealType } from '../api/nutriTypes';
import { clearActiveCaptureSessionId, readActiveCaptureSessionId, saveActiveCaptureSessionId } from '../services/mealCapture/captureSessionStorage';
import { createCaptureSession, listCaptureDrafts, loadRecognitionBootstrap, prepareCaptureImageFile, recentMealQuery, resolveDeviceTimezone, submitCaptureSession, uploadAndConfirmCaptureImage, type CaptureImageFile, type CaptureImagePreview } from '../services/mealCapture';

type Props = NativeStackScreenProps<DietStackParamList, 'Recognition'>;
type Mode = 'personal' | 'canteen';
type LoadState = 'loading' | 'ready' | 'error';

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

function toPreview(image: CaptureImage): CaptureImagePreview {
  return { uri: image.previewUrl ?? '', imageId: image.imageId, fileName: `image-${image.slotNo}`, contentType: image.contentType, byteSize: image.contentLength, capturedAt: image.capturedAt, remote: true };
}

function statusLabel(status?: string): string { return status === 'created' || status === 'uploading' ? '待提交' : status ?? '待提交'; }

export function RecognitionScreen({ navigation }: Props) {
  const { show } = useToast();
  const [mode, setMode] = useState<Mode>('personal');
  const [policy, setPolicy] = useState<CapturePolicy | null>(null);
  const [policyState, setPolicyState] = useState<LoadState>('loading');
  const [drafts, setDrafts] = useState<CaptureDraftSummary[]>([]);
  const [draftState, setDraftState] = useState<LoadState>('loading');
  const [selectedDraftId, setSelectedDraftId] = useState<string | null>(null);
  const [session, setSession] = useState<CaptureSession | null>(null);
  const [files, setFiles] = useState<Array<CaptureImageFile | CaptureImagePreview>>([]);
  const [progress, setProgress] = useState<Record<string, number>>({});
  const [uploading, setUploading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [mealType, setMealType] = useState<MealType>(() => defaultMealType());
  const [notes, setNotes] = useState('');
  const [recent, setRecent] = useState<MealHistoryItem[]>([]);
  const [historyState, setHistoryState] = useState<LoadState>('loading');

  const refreshRecent = useCallback(async () => {
    try { const result = await nutriApi.listMeals({ ...recentMealQuery(), pageSize: 6 }); setRecent(result.items); setHistoryState('ready'); }
    catch { setHistoryState('error'); }
  }, []);

  const refreshDrafts = useCallback(async (preferredId?: string | null) => {
    try {
      const result = await listCaptureDrafts();
      setDrafts(result.items); setDraftState('ready');
      const nextId = preferredId !== undefined ? (preferredId && result.items.some(item => item.captureSessionId === preferredId) ? preferredId : null) : result.items[0]?.captureSessionId ?? null;
      if (!nextId) { setSelectedDraftId(null); setSession(null); setFiles([]); return; }
      setSelectedDraftId(nextId); await saveActiveCaptureSessionId(nextId);
      const next = await nutriApi.getCaptureSession(nextId); setSession(next); setFiles(next.images.filter(image => image.status === 'confirmed').map(toPreview));
    } catch (error) { setDraftState('error'); show(`未提交草稿加载失败：${getErrorMessage(error)}`, 'error'); }
  }, [show]);

  const load = useCallback(async () => {
    setPolicy(null); setPolicyState('loading'); setDraftState('loading'); setHistoryState('loading');
    const result = await loadRecognitionBootstrap();
    if (result.policy.status === 'fulfilled') { setPolicy(result.policy.value); setPolicyState('ready'); }
    else { setPolicyState('error'); show(`无法读取上传规则：${getErrorMessage(result.policy.reason)}`, 'error'); }
    if (result.drafts.status === 'fulfilled') {
      setDrafts(result.drafts.value.items); setDraftState('ready');
      const saved = await readActiveCaptureSessionId();
      const id = saved && result.drafts.value.items.some(item => item.captureSessionId === saved) ? saved : result.drafts.value.items[0]?.captureSessionId;
      if (id) {
        try { await saveActiveCaptureSessionId(id); setSelectedDraftId(id); const restored = await nutriApi.getCaptureSession(id); setSession(restored); setFiles(restored.images.filter(image => image.status === 'confirmed').map(toPreview)); }
        catch { await clearActiveCaptureSessionId(); }
      }
    } else { setDraftState('error'); show(`未提交草稿加载失败：${getErrorMessage(result.drafts.reason)}`, 'error'); }
    if (result.history.status === 'fulfilled') { setRecent(result.history.value.items); setHistoryState('ready'); } else setHistoryState('error');
  }, [show]);

  useEffect(() => { load(); }, [load]);

  const selectDraft = useCallback(async (id: string) => {
    if (uploading || submitting || id === selectedDraftId) return;
    try { const next = await nutriApi.getCaptureSession(id); setSelectedDraftId(id); setSession(next); setFiles(next.images.filter(image => image.status === 'confirmed').map(toPreview)); setProgress({}); await saveActiveCaptureSessionId(id); }
    catch (error) { show(getErrorMessage(error), 'error'); }
  }, [selectedDraftId, show, submitting, uploading]);

  const startNew = useCallback(async () => {
    if (uploading || submitting) return;
    setSelectedDraftId(null); setSession(null); setFiles([]); setProgress({}); setNotes(''); setMealType(defaultMealType()); await clearActiveCaptureSessionId();
  }, [submitting, uploading]);

  const addImages = useCallback(async (camera: boolean) => {
    if (!policy || policyState !== 'ready') return show('上传规则尚未准备完成，请稍后重试。', 'error');
    const limit = session?.maxImageCount ?? policy.maxImageCount;
    const confirmed = session?.images.filter(item => item.status === 'confirmed').length ?? 0;
    const remaining = limit - confirmed;
    if (remaining <= 0) return show(`本次识别最多 ${limit} 张图片。`, 'error');
    try {
      const assets = await selectAssets(camera, remaining); const prepared: CaptureImageFile[] = [];
      for (const asset of assets.slice(0, remaining)) { const file = await prepareCaptureImageFile(asset); if (!policy.allowedContentTypes.includes(file.contentType)) throw new Error('该图片格式不在服务端允许范围内。'); if (file.byteSize > policy.maxFileSizeBytes) throw new Error('图片大小超过服务端限制。'); prepared.push(file); }
      if (!prepared.length) return;
      setUploading(true); let active = session ?? await createCaptureSession(resolveDeviceTimezone()); setSession(active); setSelectedDraftId(active.captureSessionId);
      for (const file of prepared) { setFiles(current => [...current, file]); active = await uploadAndConfirmCaptureImage(active.captureSessionId, file, value => setProgress(current => ({ ...current, [file.uri]: value }))); setSession(active); setProgress(current => ({ ...current, [file.uri]: 100 })); }
      await refreshDrafts(active.captureSessionId); show('图片已确认，请选择餐次和备注后提交。', 'success');
    } catch (error) { show(getErrorMessage(error), 'error'); } finally { setUploading(false); }
  }, [policy, policyState, refreshDrafts, session, show]);

  const removeImage = useCallback(async (file: CaptureImageFile | CaptureImagePreview) => {
    if (!session || uploading || submitting) return;
    if ('remote' in file) {
      try { await nutriApi.deleteCaptureImage(session.captureSessionId, file.imageId); const next = await nutriApi.getCaptureSession(session.captureSessionId); setSession(next); setFiles(next.images.filter(image => image.status === 'confirmed').map(toPreview)); await refreshDrafts(session.captureSessionId); }
      catch (error) { show(getErrorMessage(error), 'error'); }
    } else setFiles(current => current.filter(item => item.uri !== file.uri));
  }, [refreshDrafts, session, show, submitting, uploading]);

  const submit = useCallback(async () => {
    if (!session || !session.images.some(item => item.status === 'confirmed')) return show('请先拍摄或选择至少一张已确认图片。', 'error');
    if (submitting) return;
    setSubmitting(true);
    try { await submitCaptureSession(session.captureSessionId, { mealType, notes: notes.trim() || null }); await clearActiveCaptureSessionId(); setSelectedDraftId(null); setSession(null); setFiles([]); setProgress({}); setNotes(''); setMealType(defaultMealType()); await Promise.all([refreshDrafts(null), refreshRecent()]); show('餐食已入库，可以继续记录下一餐；AI 将在后台补充营养数据。', 'success'); }
    catch (error) { show(getErrorMessage(error), 'error'); } finally { setSubmitting(false); }
  }, [mealType, notes, refreshDrafts, refreshRecent, session, show, submitting]);

  const cancel = useCallback(async () => {
    if (!session) return;
    try { await nutriApi.cancelCaptureSession(session.captureSessionId); await clearActiveCaptureSessionId(); await refreshDrafts(null); show('已取消本次草稿。', 'success'); }
    catch (error) { show(getErrorMessage(error), 'error'); }
  }, [refreshDrafts, session, show]);

  const historyAction = <Pressable accessibilityLabel="查看饮食记录" onPress={() => navigation.navigate('MealHistory')} style={recognitionMetaStyles.historyAction}><List color={colors.blue} size={17} /><Text style={recognitionMetaStyles.historyActionText}>历史</Text></Pressable>;
  if (mode === 'canteen') return <PageShell pageId="recognition" action={historyAction}><ModeSwitch mode={mode} onChange={setMode} /><CanteenDemo /><RecentHistory meals={recent} state={historyState} onRetry={refreshRecent} onAll={() => navigation.navigate('MealHistory')} onOpen={mealId => navigation.navigate('MealDetail', { mealId })} /></PageShell>;

  const confirmedCount = session?.images.filter(item => item.status === 'confirmed').length ?? 0;
  const draftLimit = policy?.maxDraftSessionCount ?? null;
  return <PageShell pageId="recognition" action={historyAction}>
    <ModeSwitch mode={mode} onChange={setMode} />
    <CaptureDraftStrip drafts={drafts} selectedId={selectedDraftId} maxDrafts={draftLimit} disabled={uploading || submitting || draftState === 'loading'} onSelect={selectDraft} onNew={startNew} />
    <GlassCard style={styles.captureCard}>
      <View style={styles.scanFrame}><Camera color={colors.blue} size={35} /><View style={styles.scanLine} /></View>
      <Text style={styles.captureTitle}>把餐盘放进取景框</Text>
      <Text style={styles.captureText}>先保存为草稿，确认图片后选择餐次和备注。提交即刻入库，AI 在后台分析，不会阻塞下一餐。</Text>
      <View style={styles.actions}>{Platform.OS !== 'web' ? <AppButton label="拍照" variant="secondary" disabled={!policy || policyState !== 'ready' || uploading || submitting} onPress={() => addImages(true)} style={styles.action} /> : null}<AppButton label="从相册选择" variant="secondary" disabled={!policy || policyState !== 'ready' || uploading || submitting} onPress={() => addImages(false)} style={styles.action} /></View>
      <UploadPolicyHint policy={policy} state={policyState} onRetry={load} />
    </GlassCard>
    <CaptureImageGrid files={files} progress={progress} onRemove={session ? removeImage : undefined} />
    {session && confirmedCount > 0 ? <GlassCard style={styles.formCard}><SectionTitle title="提交餐食" detail="提交后立即进入历史，AI 稍后补充营养数据" /><Text style={styles.label}>餐次</Text><MealTypeSegmentedControl value={mealType} onChange={value => setMealType(value as MealType)} /><Text style={styles.label}>备注（选填）</Text><TextInput accessibilityLabel="餐食备注" value={notes} onChangeText={setNotes} multiline style={[inputStyle, styles.textarea]} placeholder="例如：少油、在公司食堂" placeholderTextColor="#94A3B8" /></GlassCard> : null}
    {session ? <GlassCard style={styles.sessionCard}><View style={styles.sessionHead}><View><Text style={styles.sessionTitle}>当前草稿</Text><Text style={styles.sessionMeta}>已确认 {confirmedCount}/{session.maxImageCount} 张</Text></View><Tag label={statusLabel(session.status)} tone="green" /></View><View style={styles.actions}><AppButton label={submitting ? '正在提交…' : '提交餐食'} icon={<Send color="#FFFFFF" size={16} />} disabled={submitting || uploading || confirmedCount === 0} onPress={submit} style={styles.action} /><AppButton label="取消" variant="secondary" icon={<X color={colors.ink} size={16} />} disabled={submitting || uploading} onPress={cancel} style={styles.action} /></View></GlassCard> : <Text style={styles.emptyDraft}>选择图片后才会创建新的服务端草稿。</Text>}
    <RecentHistory meals={recent} state={historyState} onRetry={refreshRecent} onAll={() => navigation.navigate('MealHistory')} onOpen={mealId => navigation.navigate('MealDetail', { mealId })} />
  </PageShell>;
}

function ModeSwitch({ mode, onChange }: { mode: Mode; onChange: (mode: Mode) => void }) { return <View style={styles.modeSwitch}>{(['personal', 'canteen'] as const).map(item => <Pressable key={item} onPress={() => onChange(item)} style={[styles.mode, mode === item && styles.modeActive]}><Text style={[styles.modeText, mode === item && styles.modeTextActive]}>{item === 'personal' ? '个人拍照' : '食堂菜单演示'}</Text></Pressable>)}</View>; }
function UploadPolicyHint({ policy, state, onRetry }: { policy: CapturePolicy | null; state: LoadState; onRetry: () => void }) { if (state === 'ready' && policy) return <Text style={styles.limit}>服务端规则：最多 {policy.maxImageCount} 张 · 单张 {(policy.maxFileSizeBytes / 1024 / 1024).toFixed(0)} MiB · 草稿最多 {policy.maxDraftSessionCount} 份</Text>; if (state === 'error') return <Pressable accessibilityRole="button" onPress={onRetry} style={recognitionMetaStyles.retry}><Text style={recognitionMetaStyles.retryText}>上传规则读取失败，点击重新加载</Text></Pressable>; return <Text style={styles.limit}>正在读取服务端上传规则…</Text>; }
function CanteenDemo() { return <><GlassCard><Tag label="演示数据" tone="amber" /><Text style={styles.canteenTitle}>食堂今日午餐</Text><Text style={styles.captureText}>固定菜单与预置营养数据，仅用于展示，不调用 NutriMemo。</Text><View style={styles.menu}><Text style={styles.menuText}>香菇鸡腿饭 · 680 kcal</Text><Text style={styles.menuText}>清炒西兰花 · 蛋白质 32 g</Text><Text style={styles.menuText}>紫菜蛋花汤 · 钠 610 mg</Text></View></GlassCard><GlassCard><SectionTitle title="演示营养报告" detail="静态示例，不会写入历史" /><NutrientMetricGrid nutrients={[{ nutrientCode: 'ENERGY_KCAL', nutrientName: '能量', amount: 570, unit: 'kcal' }, { nutrientCode: 'PROTEIN', nutrientName: '蛋白质', amount: 42, unit: 'g' }, { nutrientCode: 'CARBOHYDRATE', nutrientName: '碳水', amount: 56, unit: 'g' }, { nutrientCode: 'FAT', nutrientName: '脂肪', amount: 18, unit: 'g' }]} /></GlassCard></>; }
function RecentHistory({ meals, state, onRetry, onAll, onOpen }: { meals: MealHistoryItem[]; state: LoadState; onRetry: () => void; onAll: () => void; onOpen: (id: string) => void }) { return <><SectionTitle title="最近饮食记录" detail="最多展示 6 条" action={<Pressable onPress={onAll}><Text style={styles.all}>查看全部记录</Text></Pressable>} />{state === 'error' ? <EmptyState title="历史记录暂时无法加载" description="不影响拍照识别；请检查网络后重新加载。" action={<AppButton label="重新加载" variant="secondary" onPress={onRetry} />} /> : meals.length ? <View style={styles.recent}>{meals.map(meal => <MealHistoryRow key={meal.mealId} meal={meal} onPress={() => onOpen(meal.mealId)} />)}</View> : <EmptyState title={state === 'loading' ? '正在加载历史记录' : '还没有饮食记录'} description={state === 'loading' ? '请稍候…' : '提交餐盘照片后，记录会立即出现在这里。'} />}</>; }

const recognitionMetaStyles = StyleSheet.create({ historyAction: { flexDirection: 'row', alignItems: 'center', gap: 4, paddingHorizontal: 2, paddingVertical: 2 }, historyActionText: { color: colors.blue, fontFamily: fonts.body, fontSize: 12, fontWeight: '800' }, retry: { paddingVertical: 4 }, retryText: { color: colors.blue, fontFamily: fonts.body, fontSize: 12, fontWeight: '800' } });
const styles = StyleSheet.create({ modeSwitch: { flexDirection: 'row', borderRadius: 18, backgroundColor: '#EAF1F7', padding: 4 }, mode: { flex: 1, paddingVertical: 9, alignItems: 'center', borderRadius: 14 }, modeActive: { backgroundColor: '#FFFFFF' }, modeText: { color: colors.muted, fontFamily: fonts.body, fontSize: 13, fontWeight: '800' }, modeTextActive: { color: colors.blue }, captureCard: { alignItems: 'center', gap: 11, padding: 18 }, scanFrame: { width: 142, height: 142, borderRadius: 28, borderWidth: 2, borderColor: 'rgba(0,113,227,0.27)', borderStyle: 'dashed', backgroundColor: '#F1F8FE', alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }, scanLine: { position: 'absolute', left: 17, right: 17, height: 2, backgroundColor: colors.green, top: 69 }, captureTitle: { color: colors.ink, fontFamily: fonts.body, fontSize: 19, fontWeight: '800' }, captureText: { color: colors.muted, fontFamily: fonts.body, fontSize: 13, textAlign: 'center', lineHeight: 19 }, actions: { width: '100%', flexDirection: 'row', gap: 8 }, action: { flex: 1 }, limit: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, textAlign: 'center' }, formCard: { gap: 11 }, label: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '700' }, textarea: { minHeight: 76, textAlignVertical: 'top' }, sessionCard: { gap: 13 }, sessionHead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }, sessionTitle: { color: colors.ink, fontFamily: fonts.body, fontSize: 16, fontWeight: '800' }, sessionMeta: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, marginTop: 3 }, emptyDraft: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, textAlign: 'center' }, recent: { gap: 9 }, all: { color: colors.blue, fontFamily: fonts.body, fontWeight: '800', fontSize: 12 }, canteenTitle: { color: colors.ink, fontFamily: fonts.body, fontSize: 20, fontWeight: '800', marginTop: 10, marginBottom: 6 }, menu: { gap: 10, marginTop: 14 }, menuText: { color: colors.ink, fontFamily: fonts.body, fontSize: 14 } });
