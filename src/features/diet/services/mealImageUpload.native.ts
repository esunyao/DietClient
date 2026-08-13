import ReactNativeBlobUtil from 'react-native-blob-util';
import type { Asset } from 'react-native-image-picker';

import {
  assertMealImageSize,
  makeMealImageFileName,
  resolveCapturedAt,
  resolveMealImageMimeType,
  type MealImageFile,
  type MealImageUploadProgress,
} from './mealImageUpload.types';

/** 原生系统 URI 统一转为可供文件流读取的缓存路径。 */
async function resolveLocalPath(uri: string, extension: string): Promise<string> {
  if (uri.startsWith('file://')) return uri.slice('file://'.length);
  const response = await ReactNativeBlobUtil.config({ fileCache: true, appendExt: extension }).fetch('GET', uri);
  const path = response.path();
  return path.startsWith('file://') ? path.slice('file://'.length) : path;
}

async function readFileSize(localPath: string): Promise<number> {
  try {
    return Number((await ReactNativeBlobUtil.fs.stat(localPath)).size) || 0;
  } catch {
    return 0;
  }
}

export async function prepareMealImageFile(asset: Asset): Promise<MealImageFile> {
  if (!asset.uri) throw new Error('没有获得图片文件，请重新选择。');
  const contentType = resolveMealImageMimeType(asset);
  const extension = contentType === 'image/png' ? 'png' : contentType === 'image/webp' ? 'webp' : 'jpg';
  const localPath = await resolveLocalPath(asset.uri, extension);
  const byteSize = await readFileSize(localPath);
  // 原生少量 content URI 不会回报文件大小；交由服务端的 contentLength 校验作最后防线。
  if (byteSize > 0) assertMealImageSize(byteSize);

  return {
    uri: localPath,
    fileName: makeMealImageFileName(contentType, asset.fileName),
    contentType,
    byteSize,
    capturedAt: resolveCapturedAt(asset),
  };
}

export async function uploadMealImageBinary(
  file: MealImageFile,
  uploadUrl: string,
  requiredHeaders: Record<string, string>,
  onProgress: MealImageUploadProgress,
): Promise<void> {
  const localPath = file.uri.startsWith('file://') ? file.uri.slice('file://'.length) : file.uri;
  const response = await ReactNativeBlobUtil
    .fetch('PUT', uploadUrl, { ...requiredHeaders, 'Content-Type': file.contentType }, ReactNativeBlobUtil.wrap(localPath))
    .uploadProgress({ interval: 120 }, (sent, total) => onProgress(total > 0 ? Math.round((sent / total) * 100) : 0));
  const status = response.info().status;
  if (status < 200 || status >= 300) throw new Error(`餐食图片上传失败（HTTP ${status}）。`);
  onProgress(100);
}
