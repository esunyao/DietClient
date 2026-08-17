import type { Asset } from 'react-native-image-picker';

import { readFileSize, resolveLocalPath } from '../../../../shared/upload/nativeFile';
import { uploadFileBinary } from '../../../../shared/upload/uploadFile';
import { makeCaptureFileName, prepareCaptureMimeType, type CaptureImageFile, type CaptureUploadProgress } from './mealCapture.types';

export async function prepareCaptureImageFile(asset: Asset): Promise<CaptureImageFile> {
  if (!asset.uri) throw new Error('没有获得图片文件，请重新选择。');
  const contentType = prepareCaptureMimeType(asset);
  const extension = contentType === 'image/png' ? 'png' : contentType === 'image/webp' ? 'webp' : 'jpg';
  const uri = await resolveLocalPath(asset.uri, extension);
  return {
    uri,
    fileName: makeCaptureFileName(contentType, asset.fileName),
    contentType,
    byteSize: await readFileSize(uri),
    capturedAt: asset.timestamp ? new Date(asset.timestamp).toISOString() : null,
  };
}

export async function uploadCaptureImageBinary(file: CaptureImageFile, uploadUrl: string, requiredHeaders: Record<string, string>, onProgress: CaptureUploadProgress): Promise<void> {
  await uploadFileBinary(file.uri, uploadUrl, { ...requiredHeaders, 'Content-Type': file.contentType }, onProgress, '餐食图片上传失败');
}
