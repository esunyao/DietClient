import type { Asset } from 'react-native-image-picker';

import {
  assertMealImageSize,
  makeMealImageFileName,
  resolveCapturedAt,
  resolveMealImageMimeType,
  type MealImageFile,
  type MealImageUploadProgress,
} from './mealImageUpload.types';
import { fetchFileBlob, uploadBlob } from '../../../../shared/upload/uploadBlob';

const FAILURE_LABEL = '餐食图片上传失败';
const CORS_MESSAGE = '上传被浏览器跨域策略或网络拦截，请确认对象存储已开启 CORS。';

export async function prepareMealImageFile(asset: Asset): Promise<MealImageFile> {
  if (!asset.uri) throw new Error('没有获得图片文件，请重新选择。');
  const blob = await fetchFileBlob(asset.uri);
  const normalizedAsset: Asset = { ...asset, type: blob.type || asset.type || 'image/jpeg' };
  const contentType = resolveMealImageMimeType(normalizedAsset);
  assertMealImageSize(blob.size);
  return {
    uri: asset.uri,
    fileName: makeMealImageFileName(contentType, asset.fileName),
    contentType,
    byteSize: blob.size,
    capturedAt: resolveCapturedAt(asset),
    blob,
  };
}

export async function uploadMealImageBinary(
  file: MealImageFile,
  uploadUrl: string,
  requiredHeaders: Record<string, string>,
  onProgress: MealImageUploadProgress,
): Promise<void> {
  const blob = file.blob ?? (await fetchFileBlob(file.uri));
  await uploadBlob(
    blob,
    uploadUrl,
    { ...requiredHeaders, 'Content-Type': file.contentType },
    onProgress,
    FAILURE_LABEL,
    CORS_MESSAGE,
  );
}
