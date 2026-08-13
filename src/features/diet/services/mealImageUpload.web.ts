import type { Asset } from 'react-native-image-picker';

import {
  assertMealImageSize,
  makeMealImageFileName,
  resolveCapturedAt,
  resolveMealImageMimeType,
  type MealImageFile,
  type MealImageUploadProgress,
} from './mealImageUpload.types';

export async function prepareMealImageFile(asset: Asset): Promise<MealImageFile> {
  if (!asset.uri) throw new Error('没有获得图片文件，请重新选择。');
  const blob = await fetch(asset.uri).then(async response => {
    if (!response.ok) throw new Error('无法读取所选图片，请重新选择。');
    return response.blob();
  });
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
  const blob = file.blob ?? (await fetch(file.uri).then(response => response.blob()));
  await new Promise<void>((resolve, reject) => {
    const request = new XMLHttpRequest();
    request.open('PUT', uploadUrl);
    Object.entries({ ...requiredHeaders, 'Content-Type': file.contentType }).forEach(([name, value]) => request.setRequestHeader(name, value));
    request.upload.onprogress = event => {
      if (event.lengthComputable) onProgress(Math.round((event.loaded / event.total) * 100));
    };
    request.onerror = () => reject(new Error('上传被浏览器跨域策略或网络拦截，请确认对象存储已开启 CORS。'));
    request.onload = () => {
      if (request.status >= 200 && request.status < 300) {
        onProgress(100);
        resolve();
      } else {
        reject(new Error(`餐食图片上传失败（HTTP ${request.status}）。`));
      }
    };
    request.send(blob);
  });
}
