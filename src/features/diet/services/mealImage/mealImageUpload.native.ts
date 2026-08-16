import type { Asset } from 'react-native-image-picker';

import {
  assertMealImageSize,
  makeMealImageFileName,
  resolveCapturedAt,
  resolveMealImageMimeType,
  type MealImageFile,
  type MealImageUploadProgress,
} from './mealImageUpload.types';
import { resolveLocalPath, readFileSize } from '../../../../shared/upload/nativeFile';
import { uploadFileBinary } from '../../../../shared/upload/uploadFile';

const FAILURE_LABEL = '餐食图片上传失败';

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
  await uploadFileBinary(
    file.uri,
    uploadUrl,
    { ...requiredHeaders, 'Content-Type': file.contentType },
    onProgress,
    FAILURE_LABEL,
  );
}
