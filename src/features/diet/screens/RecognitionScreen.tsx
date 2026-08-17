import React, { useCallback, useEffect, useState } from 'react';
import { Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { launchCamera, launchImageLibrary, type Asset } from 'react-native-image-picker';
import { Camera, List, RefreshCw, Send, X } from 'lucide-react-native';

import type { DietStackParamList } from '../../../navigation/types';
import { PageShell } from '../../../navigation/components/PageShell';
import { getErrorMessage } from '../../../shared/api/client';
import { AppButton, EmptyState, GlassCard, SectionTitle, Tag, useToast } from '../../../shared/components';
import { colors, fonts } from '../../../shared/theme/tokens';
import { CaptureImageGrid, MealHistoryRow, NutrientMetricGrid } from '../components';
import { nutriApi } from '../api/nutriApi';
import type { CapturePolicy, CaptureSession, MealHistoryItem } from '../api/nutriTypes';
import { createCaptureSession, prepareCaptureImageFile, resolveDeviceTimezone, restoreCaptureSession, retryCaptureSession, submitCaptureSession, uploadAndConfirmCaptureImage, type CaptureImageFile } from '../services/mealCapture';

type Props = NativeStackScreenProps<DietStackParamList, 'Recognition'>;
type Mode = 'personal' | 'canteen';
const terminal = new Set(['completed', 'expired', 'cancelled']);

async function selectAssets(camera: boolean, remaining: number): Promise<Asset[]> {
  const result = camera
    ? await launchCamera({ mediaType: 'photo', quality: 0.9, saveToPhotos: false, assetRepresentationMode: 'compatible' })
    : await launchImageLibrary({ mediaType: 'photo', quality: 0.9, selectionLimit: remaining, assetRepresentationMode: 'compatible' });
  if (result.errorMessage) throw new Error(result.errorMessage);
  return result.assets ?? [];
}

function isWorking(status?: string): boolean { return status === 'ready_for_analysis' || status === 'analysing'; }

export function RecognitionScreen({ navigation }: Props) {
  const { show } = useToast();
  const [mode, setMode] = useState<Mode>('personal');
  const [policy, setPolicy] = useState<CapturePolicy | null>(null);
  const [session, setSession] = useState<CaptureSession | null>(null);
  const [files, setFiles] = useState<CaptureImageFile[]>([]);
  const [progress, setProgress] = useState<Record<string, number>>({});
  const [uploading, setUploading] = useState(false);
  const [recent, setRecent] = useState<MealHistoryItem[]>([]);

  const load = useCallback(async () => {
    try {
      const [nextPolicy, active, meals] = await Promise.all([nutriApi.getCapturePolicy(), restoreCaptureSession(), nutriApi.listMeals({ dateFrom: '2000-01-01', dateTo: '2100-12-31', pageSize: 6 })]);
      setPolicy(nextPolicy); setSession(active); setRecent(meals.items);
    } catch (error) { show(getErrorMessage(error), 'error'); }
  }, [show]);
  useEffect(() => { load(); }, [load]);
  useEffect(() => {
    if (!isWorking(session?.status)) return undefined;
    const timer = setInterval(() => { if (session) nutriApi.getCaptureSession(session.captureSessionId).then(setSession).catch(() => undefined); }, 10000);
    return () => clearInterval(timer);
  }, [session]);

  const addImages = useCallback(async (camera: boolean) => {
    const limit = policy?.maxImageCount ?? session?.maxImageCount ?? 10;
    const confirmed = session?.images.filter(item => item.status === 'confirmed').length ?? 0;
    const remaining = limit - confirmed;
    if (remaining <= 0) return show(`本次识别最多 ${limit} 张图片。`, 'error');
    try {
      const assets = await selectAssets(camera, remaining);
      const prepared: CaptureImageFile[] = [];
      for (const asset of assets.slice(0, remaining)) {
        const file = await prepareCaptureImageFile(asset);
        if (policy && !policy.allowedContentTypes.includes(file.contentType)) throw new Error('该图片格式不在服务端允许范围内。');
        if (policy && file.byteSize > policy.maxFileSizeBytes) throw new Error('图片大小超过服务端限制。');
        prepared.push(file);
      }
      if (!prepared.length) return;
      setUploading(true);
      let active = session ?? await createCaptureSession(resolveDeviceTimezone());
      setSession(active);
      for (const file of prepared) {
        setFiles(current => [...current, file]);
        active = await uploadAndConfirmCaptureImage(active.captureSessionId, file, value => setProgress(current => ({ ...current, [file.uri]: value })));
        setSession(active); setProgress(current => ({ ...current, [file.uri]: 100 }));
      }
      show('图片已确认，准备开始识别。', 'success');
    } catch (error) { show(getErrorMessage(error), 'error'); }
    finally { setUploading(false); }
  }, [policy, session, show]);

  const submit = useCallback(async () => {
    if (!session) return show('请先拍摄或选择至少一张餐盘图片。', 'error');
    try { setSession(await submitCaptureSession(session.captureSessionId)); show('已进入 AI 分析队列。', 'success'); } catch (error) { show(getErrorMessage(error), 'error'); }
  }, [session, show]);
  const retry = useCallback(async () => { if (!session) return; try { setSession(await retryCaptureSession(session.captureSessionId)); show('已重新提交识别。', 'success'); } catch (error) { show(getErrorMessage(error), 'error'); } }, [session, show]);
  const cancel = useCallback(async () => { if (!session) return; try { await nutriApi.cancelCaptureSession(session.captureSessionId); setSession(null); setFiles([]); setProgress({}); show('已取消本次识别。', 'success'); } catch (error) { show(getErrorMessage(error), 'error'); } }, [session, show]);

  const confirmedCount = session?.images.filter(item => item.status === 'confirmed').length ?? 0;
  if (mode === 'canteen') return <PageShell pageId="recognition"><ModeSwitch mode={mode} onChange={setMode} /><CanteenDemo /><RecentHistory meals={recent} onAll={() => navigation.navigate('MealHistory')} onOpen={mealId => navigation.navigate('MealDetail', { mealId })} /></PageShell>;
  return <PageShell pageId="recognition" action={<Pressable accessibilityLabel="查看饮食记录" onPress={() => navigation.navigate('MealHistory')}><List color={colors.blue} size={18} /></Pressable>}>
    <ModeSwitch mode={mode} onChange={setMode} />
    <GlassCard style={styles.captureCard}><View style={styles.scanFrame}><Camera color={colors.blue} size={35} /><View style={styles.scanLine} /></View><Text style={styles.captureTitle}>把餐盘放进取景框</Text><Text style={styles.captureText}>拍一张整体餐盘照片即可。AI 会在后台识别菜品、份量与营养，不需要先填写菜名或克数。</Text><View style={styles.actions}>{Platform.OS !== 'web' ? <AppButton label="拍照" variant="secondary" disabled={uploading || isWorking(session?.status)} onPress={() => addImages(true)} style={styles.action} /> : null}<AppButton label="从相册选择" variant="secondary" disabled={uploading || isWorking(session?.status)} onPress={() => addImages(false)} style={styles.action} /></View><Text style={styles.limit}>{policy ? `服务端规则：最多 ${policy.maxImageCount} 张 · 单张 ${(policy.maxFileSizeBytes / 1024 / 1024).toFixed(0)} MiB` : '正在读取服务端上传规则…'}</Text></GlassCard>
    <CaptureImageGrid files={files} progress={progress} />
    {session ? <GlassCard style={styles.sessionCard}><View style={styles.sessionHead}><View><Text style={styles.sessionTitle}>本次采集</Text><Text style={styles.sessionMeta}>已确认 {confirmedCount}/{session.maxImageCount} 张</Text></View><Tag label={session.status === 'failed' ? '识别失败' : isWorking(session.status) ? 'AI 排队中' : session.status === 'created' ? '待提交' : session.status} tone={session.status === 'failed' ? 'amber' : 'green'} /></View>{isWorking(session.status) ? <Text style={styles.queue}>图片已提交，正在等待 AI 服务处理。下方营养报告仅为静态示例，绝不会写入历史。</Text> : null}<View style={styles.actions}>{session.status === 'failed' ? <AppButton label="重新提交" icon={<RefreshCw color="#FFFFFF" size={16} />} onPress={retry} style={styles.action} /> : <AppButton label={uploading ? '正在上传…' : '开始识别'} icon={<Send color="#FFFFFF" size={16} />} disabled={uploading || confirmedCount === 0 || isWorking(session.status) || terminal.has(session.status)} onPress={submit} style={styles.action} />}<AppButton label="取消" variant="secondary" icon={<X color={colors.ink} size={16} />} disabled={isWorking(session.status)} onPress={cancel} style={styles.action} /></View></GlassCard> : null}
    {isWorking(session?.status) ? <StaticResult /> : null}
    <RecentHistory meals={recent} onAll={() => navigation.navigate('MealHistory')} onOpen={mealId => navigation.navigate('MealDetail', { mealId })} />
  </PageShell>;
}

function ModeSwitch({ mode, onChange }: { mode: Mode; onChange: (mode: Mode) => void }) { return <View style={styles.modeSwitch}>{(['personal', 'canteen'] as const).map(item => <Pressable key={item} onPress={() => onChange(item)} style={[styles.mode, mode === item && styles.modeActive]}><Text style={[styles.modeText, mode === item && styles.modeTextActive]}>{item === 'personal' ? '个人拍照' : '食堂菜单演示'}</Text></Pressable>)}</View>; }
function StaticResult() { return <GlassCard><SectionTitle title="演示营养报告" detail="静态示例，不会写入历史" /><NutrientMetricGrid nutrients={[{ nutrientCode: 'ENERGY_KCAL', nutrientName: '能量', amount: 570, unit: 'kcal' }, { nutrientCode: 'PROTEIN', nutrientName: '蛋白质', amount: 42, unit: 'g' }, { nutrientCode: 'CARBOHYDRATE', nutrientName: '碳水', amount: 56, unit: 'g' }, { nutrientCode: 'FAT', nutrientName: '脂肪', amount: 18, unit: 'g' }]} /></GlassCard>; }
function CanteenDemo() { return <><GlassCard><Tag label="演示数据" tone="amber" /><Text style={styles.canteenTitle}>食堂今日午餐</Text><Text style={styles.captureText}>固定菜单与预置营养数据，仅用于展示，不调用 NutriMemo。</Text><View style={styles.menu}><Text style={styles.menuText}>香菇鸡腿饭 · 680 kcal</Text><Text style={styles.menuText}>清炒西兰花 · 蛋白质 32 g</Text><Text style={styles.menuText}>紫菜蛋花汤 · 钠 610 mg</Text></View></GlassCard><StaticResult /></>; }
function RecentHistory({ meals, onAll, onOpen }: { meals: MealHistoryItem[]; onAll: () => void; onOpen: (id: string) => void }) { return <><SectionTitle title="最近饮食记录" detail="最多展示 6 条" action={<Pressable onPress={onAll}><Text style={styles.all}>查看全部记录</Text></Pressable>} />{meals.length ? <View style={styles.recent}>{meals.map(meal => <MealHistoryRow key={meal.mealId} meal={meal} onPress={() => onOpen(meal.mealId)} />)}</View> : <EmptyState title="还没有已分析的餐食" description="上传餐盘照片并开始识别后，结果会自动出现在这里。" />}</>; }
const styles = StyleSheet.create({ modeSwitch: { flexDirection: 'row', borderRadius: 18, backgroundColor: '#EAF1F7', padding: 4 }, mode: { flex: 1, paddingVertical: 9, alignItems: 'center', borderRadius: 14 }, modeActive: { backgroundColor: '#FFFFFF' }, modeText: { color: colors.muted, fontFamily: fonts.body, fontSize: 13, fontWeight: '800' }, modeTextActive: { color: colors.blue }, captureCard: { alignItems: 'center', gap: 11, padding: 18 }, scanFrame: { width: 142, height: 142, borderRadius: 28, borderWidth: 2, borderColor: 'rgba(0,113,227,0.27)', borderStyle: 'dashed', backgroundColor: '#F1F8FE', alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }, scanLine: { position: 'absolute', left: 17, right: 17, height: 2, backgroundColor: colors.green, top: 69 }, captureTitle: { color: colors.ink, fontFamily: fonts.body, fontSize: 19, fontWeight: '800' }, captureText: { color: colors.muted, fontFamily: fonts.body, fontSize: 13, textAlign: 'center', lineHeight: 19 }, actions: { width: '100%', flexDirection: 'row', gap: 8 }, action: { flex: 1 }, limit: { color: colors.muted, fontFamily: fonts.body, fontSize: 11 }, sessionCard: { gap: 13 }, sessionHead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }, sessionTitle: { color: colors.ink, fontFamily: fonts.body, fontSize: 16, fontWeight: '800' }, sessionMeta: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, marginTop: 3 }, queue: { color: colors.muted, fontFamily: fonts.body, fontSize: 13, lineHeight: 19 }, recent: { gap: 9 }, all: { color: colors.blue, fontFamily: fonts.body, fontWeight: '800', fontSize: 12 }, canteenTitle: { color: colors.ink, fontFamily: fonts.body, fontSize: 20, fontWeight: '800', marginTop: 10, marginBottom: 6 }, menu: { gap: 10, marginTop: 14 }, menuText: { color: colors.ink, fontFamily: fonts.body, fontSize: 14 } });
