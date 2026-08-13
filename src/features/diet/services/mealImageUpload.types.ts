import type { Asset } from 'react-native-image-picker';

export const MAX_MEAL_IMAGE_BYTES = 10 * 1024 * 1024;

export type MealImageMimeType = 'image/jpeg' | 'image/png' | 'image/webp';

export interface MealImageFile {
  uri: string;
  fileName: string;
  contentType: MealImageMimeType;
  byteSize: number;
  capturedAt: string | null;
  /** Web 端在准备阶段缓存 Blob，PUT 时复用以避免重复读取本地文件。 */
  blob?: Blob;
}

export type MealImageUploadProgress = (percent: number) => void;

const supportedTypes: MealImageMimeType[] = ['image/jpeg', 'image/png', 'image/webp'];

export function resolveMealImageMimeType(asset: Asset): MealImageMimeType {
  const contentType = asset.type?.toLowerCase() === 'image/jpg' ? 'image/jpeg' : asset.type?.toLowerCase();
  if (!contentType || !supportedTypes.includes(contentType as MealImageMimeType)) {
    throw new Error('请选择 JPG、PNG 或 WebP 格式的餐食图片。');
  }
  return contentType as MealImageMimeType;
}

export function assertMealImageSize(byteSize: number): void {
  if (!Number.isFinite(byteSize) || byteSize <= 0) {
    throw new Error('无法读取图片大小，请重新选择一张图片。');
  }
  if (byteSize > MAX_MEAL_IMAGE_BYTES) {
    throw new Error('每张餐食图片不能超过 10 MiB，请选择更小的图片。');
  }
}

export function makeMealImageFileName(contentType: MealImageMimeType, sourceName?: string): string {
  const extension = contentType === 'image/png' ? 'png' : contentType === 'image/webp' ? 'webp' : 'jpg';
  const safeName = sourceName?.replace(/[^a-zA-Z0-9._-]/g, '_');
  return safeName?.endsWith(`.${extension}`) ? safeName : `meal_${Date.now()}.${extension}`;
}

export function resolveCapturedAt(asset: Asset): string | null {
  return asset.timestamp ? new Date(asset.timestamp).toISOString() : new Date().toISOString();
}
