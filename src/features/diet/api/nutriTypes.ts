export type MealId = string;
export type MealItemId = string;
export type CaptureSessionId = string;
export type CaptureImageId = string;
export type MealType = 'breakfast' | 'lunch' | 'dinner' | 'snack' | 'other';
export type CaptureStatus = 'created' | 'uploading' | 'ready_for_analysis' | 'analysing' | 'completed' | 'failed' | 'expired' | 'cancelled';
export type MealAnalysisStatus = 'queued' | 'analysing' | 'completed' | 'failed';
export type CaptureImageStatus = 'pending' | 'confirmed' | 'deleted' | 'expired';
export type ImageContentType = 'image/jpeg' | 'image/png' | 'image/webp';

export interface NutrientValue { nutrientCode: string; nutrientName: string; unit: string; amount: number; }
export interface CapturePolicy { maxImageCount: number; maxFileSizeBytes: number; allowedContentTypes: ImageContentType[]; sessionExpiresInSeconds: number; }
export interface CaptureImage { imageId: CaptureImageId; slotNo: number; objectKey: string; contentType: ImageContentType; contentLength: number; capturedAt: string | null; status: CaptureImageStatus; createdAt: string; }
export interface CaptureSession { captureSessionId: CaptureSessionId; status: CaptureStatus; timezone: string; maxImageCount: number; expiresAt: string; analysisRequestedAt: string | null; images: CaptureImage[]; createdAt: string; updatedAt: string; }
export interface CaptureSessionCreateRequest { timezone: string; }
export interface CaptureSubmitRequest { mealType: MealType; notes?: string | null; }
export interface CaptureImagePresignRequest { fileName: string; contentType: ImageContentType; contentLength: number; capturedAt?: string | null; }
export interface PresignedCaptureUpload { imageId: CaptureImageId; uploadUrl: string; objectKey: string; expiresInSeconds: number; requiredHeaders: Record<string, string>; }

export interface MealItem { itemId: MealItemId; sequenceNo: number; displayName: string; estimatedWeightG: number | null; confidence: number | null; dataSource: 'ai' | 'manual'; userCorrected: boolean; notes: string | null; nutrients: NutrientValue[]; }
export interface Meal { mealId: MealId; captureSessionId: CaptureSessionId; mealType: MealType; consumedAt: string; timezone: string; localDate: string; notes: string | null; analysisStatus: MealAnalysisStatus; items: MealItem[]; nutrients: NutrientValue[]; createdAt: string; updatedAt: string; }
export interface MealHistoryItem { mealId: MealId; mealType: MealType; consumedAt: string; localDate: string; notes: string | null; analysisStatus: MealAnalysisStatus; nutrients: NutrientValue[]; }
export interface MealPage { items: MealHistoryItem[]; page: number; pageSize: number; total: number; }
export interface CaptureSubmission { captureSession: CaptureSession; meal: Meal; }
export interface MealCorrectionItem { itemId?: MealItemId | null; displayName: string; estimatedWeightG?: number | null; notes?: string | null; nutrients: Array<{ nutrientCode: string; amount: number }>; }
export interface MealCorrectionRequest { mealType: MealType; consumedAt: string; timezone: string; notes?: string | null; items: MealCorrectionItem[]; }
export interface MealMetadataPatchRequest { mealType?: MealType; consumedAt?: string; timezone?: string; notes?: string | null; }
export interface DailyNutritionSummary { localDate: string; mealCount: number; nutrients: NutrientValue[]; mealBreakdown: Array<{ mealType: MealType; mealCount: number; nutrients: NutrientValue[] }>; updatedAt: string; }
