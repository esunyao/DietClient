import React, { useCallback, useEffect, useState } from 'react';
import { Alert, Image, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { useFocusEffect } from '@react-navigation/native';
import { launchCamera, launchImageLibrary, type Asset } from 'react-native-image-picker';
import { ChevronRight, Clock3, ImagePlus, ListPlus, Plus, Search, Trash2, Utensils } from 'lucide-react-native';

import type { DietStackParamList } from '../../../navigation/types';
import { getErrorMessage } from '../../../shared/api/client';
import { AppButton, AppScreen, EmptyState, GlassCard, ScreenHeader, SectionTitle, Tag, inputStyle } from '../../../shared/components/ui';
import { useToast } from '../../../shared/components/Toast';
import { colors, fonts, radii, spacing } from '../../../shared/theme/tokens';
import { useSessionStore } from '../../auth/store/sessionStore';
import { nutriApi } from '../api/nutriApi';
import type { Food, FoodType, Meal, MealImage, MealType } from '../api/nutriTypes';
import { uploadConfirmedMealImage } from '../services/mealImageService';
import { prepareMealImageFile } from '../services/mealImageUpload';
import type { MealImageFile } from '../services/mealImageUpload.types';
import {
  createIdempotencyKey,
  formatLocalDateTime,
  localDateFromDate,
  mealTypeLabels,
  parseLocalDateTime,
  resolveDeviceTimezone,
  toMealItemInputs,
  type MealDraftItem,
  validateMealItems,
} from '../services/mealDraft';

type EntryProps = NativeStackScreenProps<DietStackParamList, 'MealEntry'>;
type HistoryProps = NativeStackScreenProps<DietStackParamList, 'MealHistory'>;
type DetailProps = NativeStackScreenProps<DietStackParamList, 'MealDetail'>;
type CustomFoodProps = NativeStackScreenProps<DietStackParamList, 'CustomFood'>;

const mealTypes = Object.keys(mealTypeLabels) as MealType[];
const foodTypeLabels: Record<FoodType, string> = {
  ingredient: '食材',
  dish: '菜品',
  packaged_food: '包装食品',
  beverage: '饮品',
  supplement: '补充剂',
};

const nutrientDefinitions = [
  { code: 'ENERGY_KCAL', label: '能量', unit: 'kcal', required: true },
  { code: 'PROTEIN', label: '蛋白质', unit: 'g', required: true },
  { code: 'FAT', label: '脂肪', unit: 'g', required: true },
  { code: 'CARBOHYDRATE', label: '碳水化合物', unit: 'g', required: true },
  { code: 'SUGAR', label: '糖', unit: 'g' },
  { code: 'DIETARY_FIBER', label: '膳食纤维', unit: 'g' },
  { code: 'SODIUM', label: '钠', unit: 'mg' },
  { code: 'CALCIUM', label: '钙', unit: 'mg' },
  { code: 'IRON', label: '铁', unit: 'mg' },
  { code: 'POTASSIUM', label: '钾', unit: 'mg' },
  { code: 'VITAMIN_C', label: '维生素 C', unit: 'mg' },
] as const;

function mealEmoji(type: MealType): string {
  return ({ breakfast: '🥣', lunch: '🥗', dinner: '🍲', snack: '🍎', other: '🍽️' })[type];
}

function nutrientAmount(nutrients: Meal['nutrients'], code: string): number {
  return nutrients.find(item => item.nutrientCode === code)?.amount ?? 0;
}

function formatAmount(value: number): string {
  if (!Number.isFinite(value)) return '0';
  return Number.isInteger(value) ? String(value) : value.toFixed(1).replace(/\.0$/, '');
}

function formatMealTime(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return iso;
  return `${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

function dateDaysBefore(days: number): string {
  const date = new Date();
  date.setDate(date.getDate() - days);
  return localDateFromDate(date);
}

function Field({ label, children, optional = false }: { label: string; children: React.ReactNode; optional?: boolean }) {
  return <View style={styles.field}><Text style={styles.fieldLabel}>{label}{optional ? <Text style={styles.optional}>（选填）</Text> : null}</Text>{children}</View>;
}

function MealTypePicker({ value, onChange, includeAll = false }: { value: MealType | 'all'; onChange: (value: MealType | 'all') => void; includeAll?: boolean }) {
  const choices: Array<MealType | 'all'> = includeAll ? ['all', ...mealTypes] : mealTypes;
  return <View style={styles.pillWrap}>{choices.map(type => <Pressable key={type} onPress={() => onChange(type)} style={[styles.pill, value === type && styles.pillActive]}><Text style={[styles.pillText, value === type && styles.pillTextActive]}>{type === 'all' ? '全部' : mealTypeLabels[type]}</Text></Pressable>)}</View>;
}

function FoodSearchResult({ food, onAdd }: { food: Food; onAdd: (food: Food) => void }) {
  const energy = nutrientAmount(food.nutrients, 'ENERGY_KCAL');
  return <Pressable accessibilityRole="button" onPress={() => onAdd(food)} style={styles.foodResult}>
    <View style={styles.foodResultIcon}><Utensils color={colors.green} size={17} /></View>
    <View style={styles.foodResultCopy}><Text style={styles.foodResultName}>{food.name}</Text><Text style={styles.foodResultMeta}>{foodTypeLabels[food.foodType]} · {food.scope === 'personal' ? '我的食物' : '公共食物库'}{energy ? ` · ${formatAmount(energy)} kcal/100g` : ''}</Text></View>
    <Plus color={colors.blue} size={19} />
  </Pressable>;
}

function LocalImageCard({ file, progress, onRemove }: { file: MealImageFile; progress?: number; onRemove: () => void }) {
  const imageUri = Platform.OS !== 'web' && !file.uri.startsWith('file://') ? `file://${file.uri}` : file.uri;
  return <View style={styles.localImageCard}>
    <Image source={{ uri: imageUri }} resizeMode="cover" style={styles.localImage} />
    <Pressable accessibilityLabel={`移除 ${file.fileName}`} onPress={onRemove} style={styles.imageRemove}><Trash2 color="#FFFFFF" size={14} /></Pressable>
    <Text numberOfLines={1} style={styles.localImageName}>{file.fileName}</Text>
    <Text style={styles.localImageMeta}>{progress === undefined ? `${Math.ceil(file.byteSize / 1024)} KB` : `上传中 ${progress}%`}</Text>
  </View>;
}

async function selectImages(fromCamera: boolean, limit: number): Promise<Asset[]> {
  const response = fromCamera
    ? await launchCamera({ mediaType: 'photo', quality: 0.9, saveToPhotos: false, assetRepresentationMode: 'compatible' })
    : await launchImageLibrary({ mediaType: 'photo', selectionLimit: limit, quality: 0.9, assetRepresentationMode: 'compatible' });
  if (response.errorMessage) throw new Error(response.errorMessage);
  return response.assets ?? [];
}

export function MealEntryScreen({ navigation, route }: EntryProps) {
  const { show } = useToast();
  const profileTimezone = useSessionStore(state => state.user?.timezone);
  const editingMealId = route.params?.mealId;
  const [mealType, setMealType] = useState<MealType>('lunch');
  const [consumedAt, setConsumedAt] = useState(() => formatLocalDateTime(new Date()));
  const [scenario, setScenario] = useState('');
  const [notes, setNotes] = useState('');
  const [items, setItems] = useState<MealDraftItem[]>([]);
  const [query, setQuery] = useState('');
  const [foodResults, setFoodResults] = useState<Food[]>([]);
  const [searching, setSearching] = useState(false);
  const [pendingImages, setPendingImages] = useState<MealImageFile[]>([]);
  const [existingImageCount, setExistingImageCount] = useState(0);
  const [uploadProgress, setUploadProgress] = useState<Record<string, number>>({});
  const [loadingMeal, setLoadingMeal] = useState(Boolean(editingMealId));
  const [submitting, setSubmitting] = useState(false);
  const timezone = profileTimezone || resolveDeviceTimezone();

  const addFood = useCallback((food: Food) => {
    setItems(current => {
      if (current.some(item => item.foodId === food.foodId)) {
        show('同一种食物不能重复添加', 'error');
        return current;
      }
      return [...current, { foodId: food.foodId, name: food.name, consumedAmountG: food.defaultServingG ? String(food.defaultServingG) : '', notes: '' }];
    });
  }, [show]);

  useEffect(() => {
    const createdFood = route.params?.createdFood;
    if (!createdFood) return;
    addFood(createdFood);
    navigation.setParams({ createdFood: undefined });
  }, [addFood, navigation, route.params?.createdFood]);

  useEffect(() => {
    if (!editingMealId) return;
    let alive = true;
    setLoadingMeal(true);
    nutriApi.getMeal(editingMealId).then(meal => {
      if (!alive) return;
      setMealType(meal.mealType);
      setConsumedAt(formatLocalDateTime(new Date(meal.consumedAt)));
      setScenario(meal.scenario || '');
      setNotes(meal.notes || '');
      setItems(meal.items.map(item => ({ foodId: item.foodId, name: item.foodNameSnapshot, consumedAmountG: String(item.consumedAmountG), notes: item.notes || '' })));
      setExistingImageCount(meal.images.filter(image => image.status === 'confirmed').length);
    }).catch(error => show(getErrorMessage(error), 'error')).finally(() => alive && setLoadingMeal(false));
    return () => { alive = false; };
  }, [editingMealId, show]);

  const searchFoods = useCallback(async () => {
    setSearching(true);
    try {
      setFoodResults((await nutriApi.searchFoods(query.trim())).items);
    } catch (error) {
      show(getErrorMessage(error), 'error');
    } finally {
      setSearching(false);
    }
  }, [query, show]);

  const appendAssets = useCallback(async (assets: Asset[]) => {
    const remaining = 3 - existingImageCount - pendingImages.length;
    if (remaining <= 0) return show('每条餐食最多上传 3 张图片', 'error');
    try {
      const files: MealImageFile[] = [];
      for (const asset of assets.slice(0, remaining)) files.push(await prepareMealImageFile(asset));
      setPendingImages(current => [...current, ...files]);
    } catch (error) {
      show(getErrorMessage(error), 'error');
    }
  }, [existingImageCount, pendingImages.length, show]);

  const pickImages = useCallback(async (fromCamera: boolean) => {
    const remaining = 3 - existingImageCount - pendingImages.length;
    if (remaining <= 0) return show('每条餐食最多上传 3 张图片', 'error');
    try {
      await appendAssets(await selectImages(fromCamera, fromCamera ? 1 : remaining));
    } catch (error) {
      show(getErrorMessage(error), 'error');
    }
  }, [appendAssets, existingImageCount, pendingImages.length, show]);

  const submit = useCallback(async () => {
    const itemsError = validateMealItems(items);
    if (itemsError) return show(itemsError, 'error');
    const consumedAtIso = parseLocalDateTime(consumedAt);
    if (!consumedAtIso) return show('用餐时间应为 YYYY-MM-DD HH:mm，例如 2026-08-13 12:30。', 'error');
    setSubmitting(true);
    try {
      const payload = { mealType, consumedAt: consumedAtIso, timezone, scenario: scenario.trim() || null, entrySource: 'manual' as const, notes: notes.trim() || null, items: toMealItemInputs(items) };
      const meal = editingMealId ? await nutriApi.replaceMeal(editingMealId, payload) : await nutriApi.createMeal(payload, createIdempotencyKey());
      const failures: string[] = [];
      for (const file of pendingImages) {
        try {
          await uploadConfirmedMealImage(meal.mealId, file, percent => setUploadProgress(current => ({ ...current, [file.uri]: percent })));
        } catch (error) {
          failures.push(getErrorMessage(error));
        }
      }
      if (failures.length) show(`餐食已保存；${failures.length} 张图片未完成，可在详情页重新上传。`, 'error');
      else show(editingMealId ? '餐食已更新' : '餐食已保存', 'success');
      navigation.replace('MealDetail', { mealId: meal.mealId });
    } catch (error) {
      show(getErrorMessage(error), 'error');
    } finally {
      setSubmitting(false);
      setUploadProgress({});
    }
  }, [consumedAt, editingMealId, items, mealType, navigation, notes, pendingImages, scenario, show, timezone]);

  const header = <ScreenHeader title={editingMealId ? '编辑餐食' : '记录餐食'} subtitle={timezone} onBack={navigation.canGoBack() ? () => navigation.goBack() : undefined} action={<Pressable accessibilityLabel="餐食历史" onPress={() => navigation.navigate('MealHistory')} style={styles.headerAction}><Clock3 color={colors.blue} size={17} /></Pressable>} />;
  if (loadingMeal) return <AppScreen header={header}><EmptyState title="正在加载餐食" description="请稍候…" /></AppScreen>;

  return <AppScreen header={header}>
    <GlassCard style={styles.introCard}><View style={styles.introIcon}><Utensils color="#FFFFFF" size={21} /></View><View style={styles.introCopy}><Text style={styles.introTitle}>手动记录这一餐</Text><Text style={styles.introText}>选择食物和摄入量，可附加餐盘图片。图片仅作为附件保存，不触发 AI 识别。</Text></View></GlassCard>
    <GlassCard>
      <SectionTitle title="餐食信息" />
      <View style={styles.formStack}>
        <Field label="餐次"><MealTypePicker value={mealType} onChange={value => setMealType(value as MealType)} /></Field>
        <Field label="用餐时间"><TextInput accessibilityLabel="用餐时间" value={consumedAt} onChangeText={setConsumedAt} placeholder="YYYY-MM-DD HH:mm" placeholderTextColor="#94A3B8" style={inputStyle} /></Field>
        <Field label="用餐场景" optional><TextInput accessibilityLabel="用餐场景" value={scenario} onChangeText={setScenario} placeholder="如：家中、食堂、外卖" placeholderTextColor="#94A3B8" style={inputStyle} /></Field>
        <Field label="备注" optional><TextInput accessibilityLabel="餐食备注" value={notes} onChangeText={setNotes} multiline textAlignVertical="top" placeholder="可记录口味、烹饪方式等" placeholderTextColor="#94A3B8" style={[inputStyle, styles.textArea]} /></Field>
      </View>
    </GlassCard>
    <GlassCard>
      <SectionTitle title="食物条目" detail="按实际摄入量填写克数" />
      <View style={styles.searchRow}><TextInput accessibilityLabel="搜索食物" value={query} onChangeText={setQuery} returnKeyType="search" onSubmitEditing={searchFoods} placeholder="搜索食物、品牌或别名" placeholderTextColor="#94A3B8" style={[inputStyle, styles.searchInput]} /><Pressable accessibilityLabel="搜索食物" onPress={searchFoods} style={styles.searchButton}>{searching ? <Text style={styles.searchButtonText}>…</Text> : <Search color="#FFFFFF" size={18} />}</Pressable></View>
      {foodResults.map(food => <FoodSearchResult key={food.foodId} food={food} onAdd={addFood} />)}
      {foodResults.length === 0 && query.trim() ? <Pressable onPress={() => navigation.navigate('CustomFood')} style={styles.createFoodLink}><ListPlus color={colors.blue} size={18} /><Text style={styles.createFoodText}>没有找到“{query.trim()}”？新建自定义食物</Text><ChevronRight color={colors.blue} size={16} /></Pressable> : null}
      <View style={styles.itemList}>{items.map((item, index) => <View key={`${item.foodId}-${index}`} style={styles.itemCard}><View style={styles.itemTop}><View style={styles.itemFoodIcon}><Utensils color={colors.green} size={16} /></View><Text numberOfLines={1} style={styles.itemName}>{item.name}</Text><Pressable accessibilityLabel={`移除 ${item.name}`} onPress={() => setItems(current => current.filter((_, position) => position !== index))}><Trash2 color={colors.red} size={18} /></Pressable></View><View style={styles.itemFields}><TextInput accessibilityLabel={`${item.name} 摄入克数`} value={item.consumedAmountG} onChangeText={value => setItems(current => current.map((entry, position) => position === index ? { ...entry, consumedAmountG: value.replace(/[^0-9.]/g, '') } : entry))} keyboardType="decimal-pad" placeholder="摄入克数" placeholderTextColor="#94A3B8" style={[inputStyle, styles.amountInput]} /><Text style={styles.gramUnit}>g</Text><TextInput accessibilityLabel={`${item.name} 条目备注`} value={item.notes} onChangeText={value => setItems(current => current.map((entry, position) => position === index ? { ...entry, notes: value } : entry))} placeholder="备注（选填）" placeholderTextColor="#94A3B8" style={[inputStyle, styles.itemNotesInput]} /></View></View>)}</View>
      {!items.length ? <Text style={styles.emptyItems}>从上方搜索食物后，点击结果即可添加。</Text> : null}
    </GlassCard>
    <GlassCard>
      <SectionTitle title="餐盘图片" detail={`${existingImageCount + pendingImages.length}/3 张 · JPG、PNG、WebP · 每张 10 MiB 内`} />
      <View style={styles.imageActions}>{Platform.OS !== 'web' ? <AppButton label="拍照" variant="secondary" onPress={() => pickImages(true)} style={styles.imageActionButton} /> : null}<AppButton label="从相册选择" variant="secondary" onPress={() => pickImages(false)} style={styles.imageActionButton} /></View>
      {pendingImages.length ? <View style={styles.imageGrid}>{pendingImages.map((file, index) => <LocalImageCard key={`${file.uri}-${index}`} file={file} progress={uploadProgress[file.uri]} onRemove={() => setPendingImages(current => current.filter((_, position) => position !== index))} />)}</View> : <View style={styles.imageHint}><ImagePlus color={colors.muted} size={19} /><Text style={styles.imageHintText}>未添加图片也可以保存餐食。</Text></View>}
    </GlassCard>
    <AppButton label={submitting ? (editingMealId ? '正在更新…' : '正在保存…') : (editingMealId ? '保存修改' : '保存餐食')} loading={submitting} onPress={submit} />
  </AppScreen>;
}

export function MealHistoryScreen({ navigation }: HistoryProps) {
  const { show } = useToast();
  const [dateFrom, setDateFrom] = useState(() => dateDaysBefore(6));
  const [dateTo, setDateTo] = useState(() => localDateFromDate());
  const [mealType, setMealType] = useState<MealType | 'all'>('all');
  const [meals, setMeals] = useState<Meal[]>([]);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);

  const load = useCallback(async (nextPage = 1, append = false) => {
    if (dateTo < dateFrom) return show('结束日期不能早于开始日期。', 'error');
    setLoading(true);
    try {
      const result = await nutriApi.listMeals({ dateFrom, dateTo, mealType: mealType === 'all' ? undefined : mealType, page: nextPage });
      setMeals(current => append ? [...current, ...result.items] : result.items);
      setPage(nextPage);
      setTotal(result.page.total);
    } catch (error) {
      show(getErrorMessage(error), 'error');
    } finally {
      setLoading(false);
    }
  }, [dateFrom, dateTo, mealType, show]);

  useFocusEffect(useCallback(() => { load(); }, [load]));

  return <AppScreen header={<ScreenHeader title="餐食历史" subtitle="按日期与餐次筛选" onBack={() => navigation.goBack()} />}>
    <GlassCard>
      <View style={styles.historyDates}><Field label="开始日期"><TextInput value={dateFrom} onChangeText={setDateFrom} placeholder="YYYY-MM-DD" placeholderTextColor="#94A3B8" style={inputStyle} /></Field><Field label="结束日期"><TextInput value={dateTo} onChangeText={setDateTo} placeholder="YYYY-MM-DD" placeholderTextColor="#94A3B8" style={inputStyle} /></Field></View>
      <Field label="餐次"><MealTypePicker value={mealType} includeAll onChange={value => setMealType(value)} /></Field>
      <AppButton label="应用筛选" variant="secondary" onPress={() => load()} style={styles.applyButton} />
    </GlassCard>
    <SectionTitle title="记录列表" detail={loading ? '正在加载…' : `共 ${total} 条`} />
    {meals.map(meal => <Pressable key={meal.mealId} onPress={() => navigation.navigate('MealDetail', { mealId: meal.mealId })} style={styles.historyMeal}><GlassCard style={styles.historyMealCard}><Text style={styles.historyMealEmoji}>{mealEmoji(meal.mealType)}</Text><View style={styles.historyMealCopy}><Text style={styles.historyMealTitle}>{mealTypeLabels[meal.mealType]} · {meal.items.map(item => item.foodNameSnapshot).join('、')}</Text><Text style={styles.historyMealMeta}>{formatMealTime(meal.consumedAt)} · {formatAmount(nutrientAmount(meal.nutrients, 'ENERGY_KCAL'))} kcal · {meal.images.filter(image => image.status === 'confirmed').length} 张附件</Text></View><ChevronRight color={colors.muted} size={19} /></GlassCard></Pressable>)}
    {!loading && !meals.length ? <EmptyState title="这段时间还没有餐食记录" description="返回记录一餐，餐食会自动出现在这里。" action={<AppButton label="记录餐食" onPress={() => navigation.goBack()} />} /> : null}
    {meals.length < total ? <AppButton label={loading ? '加载中…' : '加载更多'} loading={loading} variant="secondary" onPress={() => load(page + 1, true)} /> : null}
  </AppScreen>;
}

export function MealDetailScreen({ navigation, route }: DetailProps) {
  const { show } = useToast();
  const [meal, setMeal] = useState<Meal | null>(null);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setMeal(await nutriApi.getMeal(route.params.mealId));
    } catch (error) {
      show(getErrorMessage(error), 'error');
    } finally {
      setLoading(false);
    }
  }, [route.params.mealId, show]);

  useFocusEffect(useCallback(() => { load(); }, [load]));

  const addImage = useCallback(async (fromCamera: boolean) => {
    if (!meal) return;
    const confirmed = meal.images.filter(image => image.status === 'confirmed').length;
    if (confirmed >= 3) return show('每条餐食最多上传 3 张图片', 'error');
    setUploading(true);
    setProgress(0);
    try {
      const assets = await selectImages(fromCamera, fromCamera ? 1 : 3 - confirmed);
      let failed = 0;
      for (const asset of assets) {
        try {
          const file = await prepareMealImageFile(asset);
          await uploadConfirmedMealImage(meal.mealId, file, setProgress);
        } catch {
          failed += 1;
        }
      }
      await load();
      show(failed ? `已保留餐食；${failed} 张图片未完成，请重新选择后上传。` : '图片已上传', failed ? 'error' : 'success');
    } catch (error) {
      show(getErrorMessage(error), 'error');
    } finally {
      setUploading(false);
      setProgress(0);
    }
  }, [load, meal, show]);

  const removeImage = useCallback((image: MealImage) => {
    if (!meal) return;
    Alert.alert('删除附件', '删除后将不再展示此图片附件。', [
      { text: '取消', style: 'cancel' },
      { text: '删除', style: 'destructive', onPress: () => nutriApi.deleteMealImage(meal.mealId, image.imageId).then(load).then(() => show('附件已删除', 'success')).catch(error => show(getErrorMessage(error), 'error')) },
    ]);
  }, [load, meal, show]);

  const removeMeal = useCallback(() => {
    if (!meal) return;
    Alert.alert('删除餐食', '餐食会从历史和今日汇总中移除，附件将由服务端后续清理。', [
      { text: '取消', style: 'cancel' },
      { text: '删除餐食', style: 'destructive', onPress: () => nutriApi.deleteMeal(meal.mealId).then(() => { show('餐食已删除', 'success'); navigation.popToTop(); }).catch(error => show(getErrorMessage(error), 'error')) },
    ]);
  }, [meal, navigation, show]);

  const header = <ScreenHeader title="餐食详情" subtitle={meal ? `${mealTypeLabels[meal.mealType]} · ${meal.localDate}` : '正在加载'} onBack={() => navigation.goBack()} />;
  if (loading || !meal) return <AppScreen header={header}><EmptyState title="正在读取餐食" description="请稍候…" /></AppScreen>;
  const confirmedImages = meal.images.filter(image => image.status === 'confirmed');
  return <AppScreen header={header}>
    <GlassCard style={styles.detailLead}><Text style={styles.detailEmoji}>{mealEmoji(meal.mealType)}</Text><View style={styles.detailLeadCopy}><Text style={styles.detailLeadTitle}>{mealTypeLabels[meal.mealType]}</Text><Text style={styles.detailLeadMeta}>{formatMealTime(meal.consumedAt)} · {meal.scenario || '未填写场景'}</Text></View><Tag label={`${formatAmount(nutrientAmount(meal.nutrients, 'ENERGY_KCAL'))} kcal`} tone="green" /></GlassCard>
    <GlassCard><SectionTitle title="食物与摄入量" />{meal.items.map(item => <View key={item.itemId} style={styles.detailItem}><View style={styles.detailItemIcon}><Utensils color={colors.green} size={17} /></View><View style={styles.detailItemCopy}><Text style={styles.detailItemName}>{item.foodNameSnapshot}</Text>{item.notes ? <Text style={styles.detailItemNotes}>{item.notes}</Text> : null}</View><Text style={styles.detailItemAmount}>{formatAmount(item.consumedAmountG)} g</Text></View>)}</GlassCard>
    <GlassCard><SectionTitle title="本餐营养" /><View style={styles.nutritionStats}><NutritionStat label="能量" value={nutrientAmount(meal.nutrients, 'ENERGY_KCAL')} unit="kcal" /><NutritionStat label="蛋白质" value={nutrientAmount(meal.nutrients, 'PROTEIN')} unit="g" /><NutritionStat label="碳水" value={nutrientAmount(meal.nutrients, 'CARBOHYDRATE')} unit="g" /><NutritionStat label="脂肪" value={nutrientAmount(meal.nutrients, 'FAT')} unit="g" /></View></GlassCard>
    <GlassCard><SectionTitle title="图片附件" detail={`${confirmedImages.length}/3 张 · 历史图片仅显示附件信息`} />{confirmedImages.map(image => <View key={image.imageId} style={styles.attachmentRow}><View style={styles.attachmentIcon}><ImagePlus color={colors.blue} size={17} /></View><View style={styles.attachmentCopy}><Text style={styles.attachmentName}>{image.contentType.replace('image/', '').toUpperCase()} 图片</Text><Text style={styles.attachmentMeta}>{image.capturedAt ? formatMealTime(image.capturedAt) : formatMealTime(image.createdAt)}</Text></View><Pressable accessibilityLabel="删除附件" onPress={() => removeImage(image)}><Trash2 color={colors.red} size={18} /></Pressable></View>)}{!confirmedImages.length ? <Text style={styles.emptyItems}>尚未上传餐盘图片。</Text> : null}<View style={styles.imageActions}>{Platform.OS !== 'web' ? <AppButton label="拍照添加" variant="secondary" onPress={() => addImage(true)} disabled={uploading} style={styles.imageActionButton} /> : null}<AppButton label={uploading ? `上传中 ${progress}%` : '从相册添加'} variant="secondary" loading={uploading} onPress={() => addImage(false)} disabled={uploading} style={styles.imageActionButton} /></View></GlassCard>
    {meal.notes ? <GlassCard><SectionTitle title="备注" /><Text style={styles.detailNotes}>{meal.notes}</Text></GlassCard> : null}
    <View style={styles.detailActions}><AppButton label="编辑餐食" variant="secondary" onPress={() => navigation.navigate('MealEntry', { mealId: meal.mealId })} style={styles.detailAction} /><AppButton label="删除餐食" variant="danger" onPress={removeMeal} style={styles.detailAction} /></View>
  </AppScreen>;
}

function NutritionStat({ label, value, unit }: { label: string; value: number; unit: string }) {
  return <View style={styles.nutritionStat}><Text style={styles.nutritionStatValue}>{formatAmount(value)}<Text style={styles.nutritionStatUnit}> {unit}</Text></Text><Text style={styles.nutritionStatLabel}>{label}</Text></View>;
}

export function CustomFoodScreen({ navigation }: CustomFoodProps) {
  const { show } = useToast();
  const [name, setName] = useState('');
  const [foodType, setFoodType] = useState<FoodType>('dish');
  const [brandName, setBrandName] = useState('');
  const [defaultServingG, setDefaultServingG] = useState('');
  const [aliases, setAliases] = useState('');
  const [nutrients, setNutrients] = useState<Record<string, string>>({});
  const [submitting, setSubmitting] = useState(false);

  const submit = useCallback(async () => {
    if (!name.trim()) return show('请填写食物名称。', 'error');
    const payloadNutrients = nutrientDefinitions.flatMap(definition => {
      const raw = nutrients[definition.code]?.trim();
      if (!raw) return [];
      const amount = Number(raw);
      return Number.isFinite(amount) && amount >= 0 ? [{ nutrientCode: definition.code, amount }] : [];
    });
    const missing = nutrientDefinitions.filter(definition => ('required' in definition && definition.required) && !payloadNutrients.some(item => item.nutrientCode === definition.code));
    if (missing.length) return show('请填写能量、蛋白质、脂肪和碳水化合物。', 'error');
    if (Object.values(nutrients).some(value => value.trim() && (!Number.isFinite(Number(value)) || Number(value) < 0))) return show('营养素数值必须是大于或等于 0 的数字。', 'error');
    const serving = defaultServingG.trim() ? Number(defaultServingG) : null;
    if (serving !== null && (!Number.isFinite(serving) || serving <= 0 || serving > 10000)) return show('默认份量应为 0–10000g。', 'error');
    setSubmitting(true);
    try {
      const food = await nutriApi.createCustomFood({ name: name.trim(), foodType, brandName: brandName.trim() || null, defaultServingG: serving, aliases: aliases.split(/[,，]/).map(alias => alias.trim()).filter(Boolean), nutrients: payloadNutrients });
      show('自定义食物已创建，并加入当前餐食', 'success');
      navigation.navigate('MealEntry', { createdFood: food });
    } catch (error) {
      show(getErrorMessage(error), 'error');
    } finally {
      setSubmitting(false);
    }
  }, [aliases, brandName, defaultServingG, foodType, name, navigation, nutrients, show]);

  return <AppScreen header={<ScreenHeader title="新建自定义食物" subtitle="营养数据按每 100g 填写" onBack={() => navigation.goBack()} />}>
    <GlassCard><SectionTitle title="基本信息" /><View style={styles.formStack}><Field label="食物名称"><TextInput value={name} onChangeText={setName} placeholder="如：自制鸡肉卷" placeholderTextColor="#94A3B8" style={inputStyle} /></Field><Field label="食物分类"><View style={styles.pillWrap}>{(Object.keys(foodTypeLabels) as FoodType[]).map(type => <Pressable key={type} onPress={() => setFoodType(type)} style={[styles.pill, foodType === type && styles.pillActive]}><Text style={[styles.pillText, foodType === type && styles.pillTextActive]}>{foodTypeLabels[type]}</Text></Pressable>)}</View></Field><Field label="品牌"><TextInput value={brandName} onChangeText={setBrandName} placeholder="选填" placeholderTextColor="#94A3B8" style={inputStyle} /></Field><Field label="默认份量" optional><TextInput value={defaultServingG} onChangeText={value => setDefaultServingG(value.replace(/[^0-9.]/g, ''))} keyboardType="decimal-pad" placeholder="克（g）" placeholderTextColor="#94A3B8" style={inputStyle} /></Field><Field label="别名" optional><TextInput value={aliases} onChangeText={setAliases} placeholder="多个别名用逗号分隔" placeholderTextColor="#94A3B8" style={inputStyle} /></Field></View></GlassCard>
    <GlassCard><SectionTitle title="每 100g 营养成分" detail="带 * 的项目必须填写" /><View style={styles.nutrientGrid}>{nutrientDefinitions.map(definition => <View key={definition.code} style={styles.nutrientField}><Text style={styles.nutrientLabel}>{definition.label}{('required' in definition && definition.required) ? <Text style={styles.required}> *</Text> : null}</Text><View style={styles.nutrientInputWrap}><TextInput accessibilityLabel={definition.label} value={nutrients[definition.code] || ''} onChangeText={value => setNutrients(current => ({ ...current, [definition.code]: value.replace(/[^0-9.]/g, '') }))} keyboardType="decimal-pad" placeholder="0" placeholderTextColor="#94A3B8" style={[inputStyle, styles.nutrientInput]} /><Text style={styles.nutrientUnit}>{definition.unit}</Text></View></View>)}</View></GlassCard>
    <AppButton label={submitting ? '正在创建…' : '创建并加入本餐'} loading={submitting} onPress={submit} />
  </AppScreen>;
}

const styles = StyleSheet.create({
  headerAction: { width: 30, height: 30, borderRadius: 15, alignItems: 'center', justifyContent: 'center' },
  introCard: { flexDirection: 'row', gap: spacing.md, backgroundColor: '#EEF8FF' },
  introIcon: { width: 44, height: 44, borderRadius: 16, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.blue },
  introCopy: { flex: 1 },
  introTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 17, fontWeight: '800' },
  introText: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, lineHeight: 18, marginTop: 4 },
  formStack: { gap: spacing.md, marginTop: spacing.lg },
  field: { gap: 7 },
  fieldLabel: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '800' },
  optional: { color: colors.muted, fontWeight: '500' },
  textArea: { minHeight: 92, paddingTop: spacing.md },
  pillWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: 7 },
  pill: { minHeight: 34, borderRadius: radii.pill, paddingHorizontal: 12, alignItems: 'center', justifyContent: 'center', backgroundColor: '#EFF4F8' },
  pillActive: { backgroundColor: colors.blue },
  pillText: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, fontWeight: '800' },
  pillTextActive: { color: '#FFFFFF' },
  searchRow: { flexDirection: 'row', gap: spacing.sm, marginTop: spacing.lg },
  searchInput: { flex: 1 },
  searchButton: { width: 50, borderRadius: radii.md, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.blue },
  searchButtonText: { color: '#FFFFFF', fontSize: 22, fontWeight: '800' },
  foodResult: { minHeight: 62, flexDirection: 'row', alignItems: 'center', gap: spacing.sm, borderBottomWidth: 1, borderColor: colors.line, paddingVertical: spacing.sm },
  foodResultIcon: { width: 34, height: 34, borderRadius: 12, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.greenSoft },
  foodResultCopy: { flex: 1 },
  foodResultName: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '800' },
  foodResultMeta: { color: colors.muted, fontFamily: fonts.body, fontSize: 10, marginTop: 3 },
  createFoodLink: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, paddingVertical: spacing.md },
  createFoodText: { flex: 1, color: colors.blue, fontFamily: fonts.body, fontSize: 12, fontWeight: '800' },
  itemList: { gap: spacing.sm, marginTop: spacing.md },
  itemCard: { borderRadius: radii.md, backgroundColor: '#F7FAFC', borderWidth: 1, borderColor: colors.line, padding: spacing.md, gap: spacing.sm },
  itemTop: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  itemFoodIcon: { width: 28, height: 28, borderRadius: 10, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.greenSoft },
  itemName: { flex: 1, color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '800' },
  itemFields: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  amountInput: { width: 92, minHeight: 42 },
  gramUnit: { color: colors.muted, fontFamily: fonts.body, fontSize: 13, fontWeight: '700' },
  itemNotesInput: { flex: 1, minHeight: 42, fontSize: 12 },
  emptyItems: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, lineHeight: 19, textAlign: 'center', paddingVertical: spacing.md },
  imageActions: { flexDirection: 'row', gap: spacing.sm, marginTop: spacing.lg },
  imageActionButton: { flex: 1 },
  imageHint: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: spacing.sm, paddingTop: spacing.lg },
  imageHintText: { color: colors.muted, fontFamily: fonts.body, fontSize: 12 },
  imageGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginTop: spacing.lg },
  localImageCard: { width: '31%', position: 'relative' },
  localImage: { width: '100%', aspectRatio: 1, borderRadius: radii.sm, backgroundColor: colors.blueSoft },
  imageRemove: { position: 'absolute', top: 5, right: 5, width: 25, height: 25, borderRadius: 13, alignItems: 'center', justifyContent: 'center', backgroundColor: 'rgba(15,23,42,0.7)' },
  localImageName: { color: colors.ink, fontFamily: fonts.body, fontSize: 10, fontWeight: '700', marginTop: 5 },
  localImageMeta: { color: colors.muted, fontFamily: fonts.body, fontSize: 9, marginTop: 2 },
  historyDates: { flexDirection: 'row', gap: spacing.sm, marginBottom: spacing.md },
  applyButton: { marginTop: spacing.lg },
  historyMeal: { marginTop: -spacing.sm },
  historyMealCard: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  historyMealEmoji: { fontSize: 27 },
  historyMealCopy: { flex: 1 },
  historyMealTitle: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '800' },
  historyMealMeta: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, marginTop: 4 },
  detailLead: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, backgroundColor: '#EEF8FF' },
  detailEmoji: { fontSize: 34 },
  detailLeadCopy: { flex: 1 },
  detailLeadTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 18, fontWeight: '800' },
  detailLeadMeta: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, marginTop: 4 },
  detailItem: { minHeight: 58, flexDirection: 'row', alignItems: 'center', gap: spacing.sm, borderBottomWidth: 1, borderColor: colors.line },
  detailItemIcon: { width: 34, height: 34, borderRadius: 12, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.greenSoft },
  detailItemCopy: { flex: 1 },
  detailItemName: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '800' },
  detailItemNotes: { color: colors.muted, fontFamily: fonts.body, fontSize: 10, marginTop: 2 },
  detailItemAmount: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '800' },
  nutritionStats: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginTop: spacing.lg },
  nutritionStat: { width: '48%', borderRadius: radii.md, padding: spacing.md, backgroundColor: '#F7FAFC' },
  nutritionStatValue: { color: colors.ink, fontFamily: fonts.display, fontSize: 18, fontWeight: '800' },
  nutritionStatUnit: { color: colors.muted, fontFamily: fonts.body, fontSize: 10 },
  nutritionStatLabel: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, marginTop: 4 },
  attachmentRow: { minHeight: 58, flexDirection: 'row', alignItems: 'center', gap: spacing.sm, borderBottomWidth: 1, borderColor: colors.line },
  attachmentIcon: { width: 34, height: 34, borderRadius: 12, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.blueSoft },
  attachmentCopy: { flex: 1 },
  attachmentName: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '800' },
  attachmentMeta: { color: colors.muted, fontFamily: fonts.body, fontSize: 10, marginTop: 2 },
  detailNotes: { color: colors.muted, fontFamily: fonts.body, fontSize: 13, lineHeight: 20, marginTop: spacing.md },
  detailActions: { flexDirection: 'row', gap: spacing.sm },
  detailAction: { flex: 1 },
  nutrientGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginTop: spacing.lg },
  nutrientField: { width: '48%', gap: 6 },
  nutrientLabel: { color: colors.ink, fontFamily: fonts.body, fontSize: 12, fontWeight: '700' },
  required: { color: colors.red },
  nutrientInputWrap: { position: 'relative' },
  nutrientInput: { minHeight: 44, fontSize: 13, paddingRight: 36 },
  nutrientUnit: { position: 'absolute', right: 10, top: 14, color: colors.muted, fontFamily: fonts.body, fontSize: 10, fontWeight: '700' },
});
