import type { Asset } from 'react-native-image-picker';

import { fetchFileBlob, uploadBlob } from '../../../../shared/upload/uploadBlob';
import { makeCaptureFileName, prepareCaptureMimeType, type CaptureImageFile, type CaptureUploadProgress } from './mealCapture.types';

export async function prepareCaptureImageFile(asset: Asset): Promise<CaptureImageFile> {
  if (!asset.uri) throw new Error('没有获得图片文件，请重新选择。');
  const blob = await fetchFileBlob(asset.uri);
  const contentType = prepareCaptureMimeType({ ...asset, type: blob.type || asset.type || 'image/jpeg' });
  return { uri: asset.uri, fileName: makeCaptureFileName(contentType, asset.fileName), contentType, byteSize: blob.size, capturedAt: asset.timestamp ? new Date(asset.timestamp).toISOString() : null, blob };
}

export async function uploadCaptureImageBinary(file: CaptureImageFile, uploadUrl: string, requiredHeaders: Record<string, string>, onProgress: CaptureUploadProgress): Promise<void> {
  await uploadBlob(file.blob ?? (await fetchFileBlob(file.uri)), uploadUrl, { ...requiredHeaders, 'Content-Type': file.contentType }, onProgress, '餐食图片上传失败', '上传被浏览器跨域策略或网络拦截，请确认对象存储已开启 CORS。');
}
