/** NutriMemo 返回的雪花 ID 均以字符串保存，避免 JavaScript number 丢失精度。 */
export type FoodId = string;
export type MealId = string;
export type MealImageId = string;

export type FoodType = 'ingredient' | 'dish' | 'packaged_food' | 'beverage' | 'supplement';
export type MealType = 'breakfast' | 'lunch' | 'dinner' | 'snack' | 'other';
export type EntrySource = 'manual' | 'photo_placeholder' | 'import';

export interface NutrientValue {
  nutrientCode: string;
  nutrientName: string;
  unit: string;
  amount: number;
}

export interface NutrientInput {
  nutrientCode: string;
  amount: number;
}

export interface Food {
  foodId: FoodId;
  scope: 'public' | 'personal';
  name: string;
  foodType: FoodType;
  brandName: string | null;
  defaultServingG: number | null;
  aliases: string[];
  active: boolean;
  nutrients: NutrientValue[];
  version: number;
  createdAt: string;
  updatedAt: string;
}

export interface FoodPage {
  items: Food[];
  page: { page: number; pageSize: number; total: number };
}

export interface CustomFoodRequest {
  name: string;
  foodType: FoodType;
  brandName?: string | null;
  defaultServingG?: number | null;
  aliases: string[];
  nutrients: NutrientInput[];
}

export interface MealItemInput {
  foodId: FoodId;
  consumedAmountG: number;
  displayName?: string | null;
  notes?: string | null;
}

export interface MealUpsertRequest {
  mealType: MealType;
  consumedAt: string;
  timezone: string;
  scenario?: string | null;
  entrySource: EntrySource;
  notes?: string | null;
  items: MealItemInput[];
}

export interface MealItem {
  itemId: string;
  sequenceNo: number;
  foodId: FoodId | null;
  foodVersion: number | null;
  foodNameSnapshot: string;
  consumedAmountG: number;
  notes: string | null;
  nutrientSnapshots: NutrientValue[];
  createdAt: string;
}

export interface MealImage {
  imageId: MealImageId;
  objectKey: string;
  contentType: 'image/jpeg' | 'image/png' | 'image/webp';
  capturedAt: string | null;
  status: 'pending' | 'confirmed' | 'deleted';
  createdAt: string;
}

export interface Meal {
  mealId: MealId;
  mealType: MealType;
  consumedAt: string;
  timezone: string;
  localDate: string;
  scenario: string | null;
  entrySource: EntrySource;
  notes: string | null;
  status: 'active' | 'deleted';
  items: MealItem[];
  images: MealImage[];
  nutrients: NutrientValue[];
  createdAt: string;
  updatedAt: string;
}

export interface MealPage {
  items: Meal[];
  page: { page: number; pageSize: number; total: number };
}

export interface MealImagePresignRequest {
  fileName: string;
  contentType: MealImage['contentType'];
  contentLength: number;
  capturedAt?: string | null;
}

export interface PresignedUrl {
  uploadUrl: string;
  objectKey: string;
  expiresInSeconds: number;
  requiredHeaders: Record<string, string>;
}

export interface DailyNutritionSummary {
  localDate: string;
  mealCount: number;
  nutrients: NutrientValue[];
  mealBreakdown: Array<{ mealType: MealType; mealCount: number; nutrients: NutrientValue[] }>;
  updatedAt: string;
}
