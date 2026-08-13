import { apiClient, assertApiSuccess, unwrapApiResponse } from '../../../shared/api/client';
import type { ApiEnvelope } from '../../../shared/types/api';
import type {
  CustomFoodRequest,
  DailyNutritionSummary,
  Food,
  FoodPage,
  Meal,
  MealId,
  MealImage,
  MealImageId,
  MealImagePresignRequest,
  MealPage,
  MealType,
  MealUpsertRequest,
  PresignedUrl,
} from './nutriTypes';

const path = 'v1/nutri';

export type MealListQuery = {
  dateFrom: string;
  dateTo: string;
  mealType?: MealType;
  page?: number;
  pageSize?: number;
};

export const nutriApi = {
  searchFoods: async (query?: string, page = 1): Promise<FoodPage> => {
    const response = await apiClient.get<ApiEnvelope<FoodPage>>(`${path}/foods`, {
      params: { q: query || undefined, includeCustom: true, page, pageSize: 20 },
    });
    return unwrapApiResponse(response);
  },

  createCustomFood: async (payload: CustomFoodRequest): Promise<Food> => {
    const response = await apiClient.post<ApiEnvelope<Food>>(`${path}/custom-foods`, payload);
    return unwrapApiResponse(response);
  },

  listMeals: async (query: MealListQuery): Promise<MealPage> => {
    const response = await apiClient.get<ApiEnvelope<MealPage>>(`${path}/meals`, {
      params: { ...query, page: query.page ?? 1, pageSize: query.pageSize ?? 20 },
    });
    return unwrapApiResponse(response);
  },

  getMeal: async (mealId: MealId): Promise<Meal> => {
    const response = await apiClient.get<ApiEnvelope<Meal>>(`${path}/meals/${encodeURIComponent(mealId)}`);
    return unwrapApiResponse(response);
  },

  createMeal: async (payload: MealUpsertRequest, idempotencyKey: string): Promise<Meal> => {
    const response = await apiClient.post<ApiEnvelope<Meal>>(`${path}/meals`, payload, {
      headers: { 'X-Idempotency-Key': idempotencyKey },
    });
    return unwrapApiResponse(response);
  },

  replaceMeal: async (mealId: MealId, payload: MealUpsertRequest): Promise<Meal> => {
    const response = await apiClient.put<ApiEnvelope<Meal>>(`${path}/meals/${encodeURIComponent(mealId)}`, payload);
    return unwrapApiResponse(response);
  },

  deleteMeal: async (mealId: MealId): Promise<void> => {
    const response = await apiClient.delete<ApiEnvelope<unknown>>(`${path}/meals/${encodeURIComponent(mealId)}`);
    assertApiSuccess(response);
  },

  presignMealImage: async (mealId: MealId, payload: MealImagePresignRequest): Promise<PresignedUrl> => {
    const response = await apiClient.post<ApiEnvelope<PresignedUrl>>(`${path}/meals/${encodeURIComponent(mealId)}/images/presign`, payload);
    return unwrapApiResponse(response);
  },

  confirmMealImage: async (mealId: MealId, objectKey: string, capturedAt?: string | null): Promise<MealImage> => {
    const response = await apiClient.post<ApiEnvelope<MealImage>>(
      `${path}/meals/${encodeURIComponent(mealId)}/images/confirm`,
      { objectKey, capturedAt: capturedAt ?? null },
    );
    return unwrapApiResponse(response);
  },

  deleteMealImage: async (mealId: MealId, imageId: MealImageId): Promise<void> => {
    const response = await apiClient.delete<ApiEnvelope<unknown>>(`${path}/meals/${encodeURIComponent(mealId)}/images/${encodeURIComponent(imageId)}`);
    assertApiSuccess(response);
  },

  getDailySummary: async (localDate: string): Promise<DailyNutritionSummary> => {
    const response = await apiClient.get<ApiEnvelope<DailyNutritionSummary>>(`${path}/summaries/daily`, { params: { localDate } });
    return unwrapApiResponse(response);
  },
};
