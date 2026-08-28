import React, { useCallback, useEffect, useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { Plus, Trash2 } from 'lucide-react-native';

import type { DietStackParamList } from '../../../navigation/types';
import { PageShell } from '../../../navigation/components/PageShell';
import { getErrorMessage } from '../../../shared/api/client';
import {
  AppButton,
  DateWheelField,
  EmptyState,
  GlassCard,
  NumericWheelField,
  SectionTitle,
  inputStyle,
  useToast,
} from '../../../shared/components';
import { colors, fonts } from '../../../shared/theme/tokens';
import { MealTypeSegmentedControl } from '../components';
import { nutriApi } from '../api/nutriApi';
import type { MealCorrectionItem, MealType } from '../api/nutriTypes';
import {
  emptyCorrectionItem,
  mealToCorrectionDraft,
  serializeMealCorrection,
  serializeMealMetadata,
  type MealCorrectionDraft,
} from '../services/mealCorrection';

type Props = NativeStackScreenProps<DietStackParamList, 'MealCorrection'>;
export function MealCorrectionScreen({ navigation, route }: Props) {
  const { show } = useToast();
  const [draft, setDraft] = useState<MealCorrectionDraft | null>(null);
  const [saving, setSaving] = useState(false);
  useEffect(() => {
    nutriApi
      .getMeal(route.params.mealId)
      .then(meal => setDraft(mealToCorrectionDraft(meal)))
      .catch(error => show(getErrorMessage(error), 'error'));
  }, [route.params.mealId, show]);
  const updateItem = useCallback(
    (index: number, mutate: (item: MealCorrectionItem) => MealCorrectionItem) =>
      setDraft(current =>
        current
          ? {
              ...current,
              items: current.items.map((item, position) =>
                position === index ? mutate(item) : item,
              ),
            }
          : current,
      ),
    [],
  );
  const save = useCallback(async () => {
    if (!draft) return;
    if (draft.items.some(item => !item.displayName.trim()))
      return show('每个餐食项都需要名称。', 'error');
    setSaving(true);
    try {
      if (draft.items.length)
        await nutriApi.replaceMeal(route.params.mealId, serializeMealCorrection(draft));
      else await nutriApi.patchMeal(route.params.mealId, serializeMealMetadata(draft));
      show('本餐已修正，营养汇总已重算。', 'success');
      navigation.replace('MealDetail', { mealId: route.params.mealId });
    } catch (error) {
      show(getErrorMessage(error), 'error');
    } finally {
      setSaving(false);
    }
  }, [draft, navigation, route.params.mealId, show]);
  if (!draft)
    return (
      <PageShell pageId="mealCorrection" onBack={() => navigation.goBack()}>
        <EmptyState title="正在加载可修正内容" description="请稍候…" />
      </PageShell>
    );
  return (
    <PageShell pageId="mealCorrection" onBack={() => navigation.goBack()}>
      <GlassCard style={styles.form}>
        <DateWheelField
          label="用餐时间"
          value={draft.consumedAt}
          onChange={value =>
            setDraft(current => (current ? { ...current, consumedAt: value } : current))
          }
          mode="datetime"
        />
        <Text style={styles.label}>餐次</Text>
        <MealTypeSegmentedControl
          value={draft.mealType}
          onChange={value =>
            setDraft(current => (current ? { ...current, mealType: value as MealType } : current))
          }
        />
        <Text style={styles.label}>备注（选填）</Text>
        <TextInput
          accessibilityLabel="餐食备注"
          value={draft.notes}
          onChangeText={notes => setDraft(current => (current ? { ...current, notes } : current))}
          multiline
          style={[inputStyle, styles.textarea]}
          placeholder="补充本餐的说明"
          placeholderTextColor="#94A3B8"
        />
      </GlassCard>
      <SectionTitle title="餐食项与营养值" detail="修改后自动重算" />
      {draft.items.map((item, index) => (
        <GlassCard key={`${item.itemId ?? 'new'}-${index}`} style={styles.itemCard}>
          <View style={styles.itemHead}>
            <Text style={styles.itemIndex}>餐食项 {index + 1}</Text>
            <Pressable
              accessibilityLabel="删除餐食项"
              onPress={() =>
                setDraft(current =>
                  current
                    ? {
                        ...current,
                        items: current.items.filter((_, position) => position !== index),
                      }
                    : current,
                )
              }
            >
              <Trash2 color={colors.red} size={18} />
            </Pressable>
          </View>
          <TextInput
            accessibilityLabel={`餐食项 ${index + 1} 名称`}
            value={item.displayName}
            onChangeText={displayName =>
              updateItem(index, current => ({ ...current, displayName }))
            }
            style={inputStyle}
            placeholder="菜品名称"
            placeholderTextColor="#94A3B8"
          />
          <NumericWheelField
            label="估算重量"
            value={
              item.estimatedWeightG === null || item.estimatedWeightG === undefined
                ? ''
                : String(item.estimatedWeightG)
            }
            onChange={value =>
              updateItem(index, current => ({
                ...current,
                estimatedWeightG: value === '' ? null : Number(value.replace(/[^0-9.]/g, '')),
              }))
            }
            minimum={0}
            maximum={100000}
            step={1}
            unit="g"
            placeholder="选填"
          />
          <View style={styles.nutrients}>
            {item.nutrients.map((nutrient, nutrientIndex) => (
              <View key={nutrient.nutrientCode} style={styles.nutrient}>
                <Text style={styles.nutrientName}>{nutrient.nutrientCode}</Text>
                <TextInput
                  accessibilityLabel={`${item.displayName} ${nutrient.nutrientCode}`}
                  value={String(nutrient.amount)}
                  onChangeText={value =>
                    updateItem(index, current => ({
                      ...current,
                      nutrients: current.nutrients.map((entry, position) =>
                        position === nutrientIndex
                          ? { ...entry, amount: Number(value.replace(/[^0-9.]/g, '')) || 0 }
                          : entry,
                      ),
                    }))
                  }
                  keyboardType="decimal-pad"
                  style={[inputStyle, styles.amount]}
                />
                <Text style={styles.unit}>数值</Text>
              </View>
            ))}
          </View>
          <Pressable
            onPress={() =>
              updateItem(index, current => ({
                ...current,
                nutrients: [...current.nutrients, { nutrientCode: 'SODIUM', amount: 0 }],
              }))
            }
            style={styles.addNutrient}
          >
            <Plus color={colors.blue} size={15} />
            <Text style={styles.addNutrientText}>增加钠营养项</Text>
          </Pressable>
        </GlassCard>
      ))}
      <AppButton
        label="增加餐食项"
        variant="secondary"
        icon={<Plus color={colors.ink} size={17} />}
        onPress={() =>
          setDraft(current =>
            current ? { ...current, items: [...current.items, emptyCorrectionItem()] } : current,
          )
        }
      />
      <AppButton label="保存修正" loading={saving} onPress={save} />
    </PageShell>
  );
}
const styles = StyleSheet.create({
  form: { gap: 11 },
  label: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '700' },
  textarea: { minHeight: 76, textAlignVertical: 'top' },
  itemCard: { gap: 11 },
  itemHead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  itemIndex: { color: colors.ink, fontFamily: fonts.body, fontSize: 16, fontWeight: '800' },
  nutrients: { gap: 8 },
  nutrient: { flexDirection: 'row', alignItems: 'center', gap: 7 },
  nutrientName: {
    flex: 1,
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
    fontWeight: '700',
  },
  amount: { width: 95, paddingVertical: 8 },
  unit: { color: colors.muted, fontFamily: fonts.body, fontSize: 11 },
  addNutrient: { flexDirection: 'row', alignItems: 'center', gap: 5, paddingVertical: 5 },
  addNutrientText: { color: colors.blue, fontFamily: fonts.body, fontSize: 12, fontWeight: '800' },
});
