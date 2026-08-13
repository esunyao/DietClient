import 'react-native-get-random-values';

import type { FoodId, MealItemInput, MealType } from '../api/nutriTypes';

export type MealDraftItem = {
  foodId: FoodId | null;
  name: string;
  consumedAmountG: string;
  notes: string;
};

export const mealTypeLabels: Record<MealType, string> = {
  breakfast: '早餐',
  lunch: '午餐',
  dinner: '晚餐',
  snack: '加餐',
  other: '其他',
};

export function formatLocalDateTime(date: Date): string {
  const pad = (value: number) => String(value).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

export function parseLocalDateTime(value: string): string | null {
  const match = value.trim().match(/^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})$/);
  if (!match) return null;
  const [, year, month, day, hour, minute] = match.map(Number);
  const date = new Date(year, month - 1, day, hour, minute);
  if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day || date.getHours() !== hour || date.getMinutes() !== minute) return null;
  return date.toISOString();
}

export function localDateFromDate(date = new Date()): string {
  return formatLocalDateTime(date).slice(0, 10);
}

export function resolveDeviceTimezone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
  } catch {
    return 'UTC';
  }
}

export function validateMealItems(items: MealDraftItem[]): string | null {
  if (!items.length) return '请至少添加一种食物。';
  const foodIds = new Set<string>();
  for (const item of items) {
    if (!item.foodId) return `“${item.name}”已不可用，请重新选择食物。`;
    if (foodIds.has(item.foodId)) return '同一餐次不能重复添加同一种食物。';
    foodIds.add(item.foodId);
    const amount = Number(item.consumedAmountG);
    if (!Number.isFinite(amount) || amount <= 0 || amount > 100000) return `请为“${item.name}”填写 0–100000g 的摄入量。`;
  }
  return null;
}

export function toMealItemInputs(items: MealDraftItem[]): MealItemInput[] {
  return items.map(item => ({
    foodId: item.foodId!,
    consumedAmountG: Number(item.consumedAmountG),
    notes: item.notes.trim() || null,
  }));
}

/** 不引入新依赖的 UUID v4，专门用于创建餐次幂等键。 */
export function createIdempotencyKey(): string {
  const bytes = new Uint8Array(16);
  const cryptoApi = (globalThis as unknown as { crypto?: { getRandomValues: (value: Uint8Array) => Uint8Array } }).crypto;
  if (!cryptoApi?.getRandomValues) throw new Error('当前设备不支持安全随机数，无法提交餐食。');
  cryptoApi.getRandomValues(bytes);
  bytes[6] = (bytes[6] % 16) + 64;
  bytes[8] = (bytes[8] % 64) + 128;
  const hex = Array.from(bytes, value => value.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}
