import type {
  Meal,
  MealCorrectionItem,
  MealCorrectionRequest,
  MealMetadataPatchRequest,
  MealType,
  NutrientValue,
} from '../../api/nutriTypes';

export const mealTypeLabels: Record<MealType, string> = {
  breakfast: '早餐',
  lunch: '午餐',
  dinner: '晚餐',
  snack: '加餐',
  other: '其他',
};

export const coreNutrients = [
  { nutrientCode: 'ENERGY_KCAL', nutrientName: '能量', unit: 'kcal' },
  { nutrientCode: 'PROTEIN', nutrientName: '蛋白质', unit: 'g' },
  { nutrientCode: 'FAT', nutrientName: '脂肪', unit: 'g' },
  { nutrientCode: 'CARBOHYDRATE', nutrientName: '碳水化合物', unit: 'g' },
] as const;

export interface MealCorrectionDraft {
  consumedAt: string;
  mealType: MealType;
  timezone: string;
  notes: string;
  items: MealCorrectionItem[];
}

function cloneNutrients(values: NutrientValue[]): NutrientValue[] {
  return values.map(value => ({ ...value }));
}

export function mealToCorrectionDraft(meal: Meal): MealCorrectionDraft {
  return {
    consumedAt: meal.consumedAt,
    mealType: meal.mealType,
    timezone: meal.timezone,
    notes: meal.notes ?? '',
    items: meal.items.map(item => ({
      itemId: item.itemId,
      displayName: item.displayName,
      estimatedWeightG: item.estimatedWeightG,
      notes: item.notes,
      nutrients: cloneNutrients(item.nutrients),
    })),
  };
}

export function emptyCorrectionItem(): MealCorrectionItem {
  return {
    displayName: '新菜品',
    estimatedWeightG: null,
    nutrients: coreNutrients.map(item => ({ ...item, amount: 0 })),
  };
}

export function serializeMealCorrection(draft: MealCorrectionDraft): MealCorrectionRequest {
  return {
    consumedAt: draft.consumedAt,
    mealType: draft.mealType,
    timezone: draft.timezone,
    notes: draft.notes.trim() || null,
    items: draft.items.map(item => ({
      itemId: item.itemId ?? null,
      displayName: item.displayName.trim() || '未命名菜品',
      estimatedWeightG: item.estimatedWeightG === null ? null : Number(item.estimatedWeightG),
      nutrients: item.nutrients.map(value => ({ ...value, amount: Number(value.amount) || 0 })),
    })),
  };
}

export function serializeMealMetadata(draft: MealCorrectionDraft): MealMetadataPatchRequest {
  return {
    mealType: draft.mealType,
    consumedAt: draft.consumedAt,
    timezone: draft.timezone,
    notes: draft.notes.trim() || null,
  };
}
