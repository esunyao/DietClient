import { apiClient, assertApiSuccess, unwrapApiResponse } from '../../../shared/api/client';
import type { ApiEnvelope } from '../../../shared/types/api';
import type {
  CaptureImage,
  CaptureImageId,
  CaptureImagePresignRequest,
  CapturePolicy,
  CaptureSession,
  CaptureSessionCreateRequest,
  CaptureSessionId,
  DailyNutritionSummary,
  Meal,
  MealCorrectionRequest,
  MealId,
  MealPage,
  MealType,
  PresignedCaptureUpload,
} from './nutriTypes';

const path = 'v1/nutri';

export type MealListQuery = { dateFrom: string; dateTo: string; mealType?: MealType; q?: string; page?: number; pageSize?: number; };

export const nutriApi = {
  getCapturePolicy: async (): Promise<CapturePolicy> => unwrapApiResponse(await apiClient.get<ApiEnvelope<CapturePolicy>>(`${path}/capture-policy`)),
  createCaptureSession: async (payload: CaptureSessionCreateRequest, idempotencyKey: string): Promise<CaptureSession> => unwrapApiResponse(await apiClient.post<ApiEnvelope<CaptureSession>>(`${path}/capture-sessions`, payload, { headers: { 'X-Idempotency-Key': idempotencyKey } })),
  getCaptureSession: async (sessionId: CaptureSessionId): Promise<CaptureSession> => unwrapApiResponse(await apiClient.get<ApiEnvelope<CaptureSession>>(`${path}/capture-sessions/${encodeURIComponent(sessionId)}`)),
  presignCaptureImage: async (sessionId: CaptureSessionId, payload: CaptureImagePresignRequest): Promise<PresignedCaptureUpload> => unwrapApiResponse(await apiClient.post<ApiEnvelope<PresignedCaptureUpload>>(`${path}/capture-sessions/${encodeURIComponent(sessionId)}/images/presign`, payload)),
  confirmCaptureImage: async (sessionId: CaptureSessionId, imageId: CaptureImageId): Promise<CaptureImage> => unwrapApiResponse(await apiClient.post<ApiEnvelope<CaptureImage>>(`${path}/capture-sessions/${encodeURIComponent(sessionId)}/images/${encodeURIComponent(imageId)}/confirm`)),
  deleteCaptureImage: async (sessionId: CaptureSessionId, imageId: CaptureImageId): Promise<void> => { assertApiSuccess(await apiClient.delete<ApiEnvelope<unknown>>(`${path}/capture-sessions/${encodeURIComponent(sessionId)}/images/${encodeURIComponent(imageId)}`)); },
  submitCaptureSession: async (sessionId: CaptureSessionId): Promise<CaptureSession> => unwrapApiResponse(await apiClient.post<ApiEnvelope<CaptureSession>>(`${path}/capture-sessions/${encodeURIComponent(sessionId)}/submit`)),
  retryCaptureSession: async (sessionId: CaptureSessionId): Promise<CaptureSession> => unwrapApiResponse(await apiClient.post<ApiEnvelope<CaptureSession>>(`${path}/capture-sessions/${encodeURIComponent(sessionId)}/retry`)),
  cancelCaptureSession: async (sessionId: CaptureSessionId): Promise<void> => { assertApiSuccess(await apiClient.delete<ApiEnvelope<unknown>>(`${path}/capture-sessions/${encodeURIComponent(sessionId)}`)); },
  listMeals: async (query: MealListQuery): Promise<MealPage> => unwrapApiResponse(await apiClient.get<ApiEnvelope<MealPage>>(`${path}/meals`, { params: { ...query, page: query.page ?? 1, pageSize: query.pageSize ?? 20 } })),
  getMeal: async (mealId: MealId): Promise<Meal> => unwrapApiResponse(await apiClient.get<ApiEnvelope<Meal>>(`${path}/meals/${encodeURIComponent(mealId)}`)),
  replaceMeal: async (mealId: MealId, payload: MealCorrectionRequest): Promise<Meal> => unwrapApiResponse(await apiClient.put<ApiEnvelope<Meal>>(`${path}/meals/${encodeURIComponent(mealId)}`, payload)),
  deleteMeal: async (mealId: MealId): Promise<void> => { assertApiSuccess(await apiClient.delete<ApiEnvelope<unknown>>(`${path}/meals/${encodeURIComponent(mealId)}`)); },
  getDailySummary: async (localDate: string): Promise<DailyNutritionSummary> => unwrapApiResponse(await apiClient.get<ApiEnvelope<DailyNutritionSummary>>(`${path}/summaries/daily`, { params: { localDate } })),
};
