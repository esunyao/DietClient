import { nutriApi } from '../api/nutriApi';
import type { MealId } from '../api/nutriTypes';
import { uploadMealImageBinary } from './mealImageUpload';
import type { MealImageFile, MealImageUploadProgress } from './mealImageUpload.types';

/** 完成单张附件的“预签名 → 对象存储 PUT → 服务端确认”链路。 */
export async function uploadConfirmedMealImage(
  mealId: MealId,
  file: MealImageFile,
  onProgress: MealImageUploadProgress,
): Promise<void> {
  if (file.byteSize <= 0) throw new Error('无法确认图片大小，请重新选择一张图片。');
  const presign = await nutriApi.presignMealImage(mealId, {
    fileName: file.fileName,
    contentType: file.contentType,
    contentLength: file.byteSize,
    capturedAt: file.capturedAt,
  });
  await uploadMealImageBinary(file, presign.uploadUrl, presign.requiredHeaders, onProgress);
  await nutriApi.confirmMealImage(mealId, presign.objectKey, file.capturedAt);
}
