import type { Asset } from 'react-native-image-picker';

import { assertAvatarSize, makeAvatarFileName, resolveAvatarMimeType, type AvatarFile, type AvatarUploadProgress } from './avatarUpload.types';
import { fetchFileBlob, uploadBlob } from '../../../../shared/upload/uploadBlob';

const FAILURE_LABEL = '头像文件上传失败';
const CORS_MESSAGE = '上传被浏览器跨域策略或网络拦截，请确认对象存储已开启 CORS 并允许本机地址访问。';

/** Web 端图片选择器提供 data URI / blob URL；转成 Blob 后才能正确 PUT 到对象存储。 */
export async function prepareAvatarFile(asset: Asset): Promise<AvatarFile> {
  if (!asset.uri) {
    throw new Error('没有获得图片文件，请重新选择。');
  }

  const blob = await fetchFileBlob(asset.uri);
  const normalizedAsset: Asset = { ...asset, type: blob.type || asset.type || 'image/jpeg' };
  const contentType = resolveAvatarMimeType(normalizedAsset);
  assertAvatarSize(blob.size);

  return {
    uri: asset.uri,
    fileName: makeAvatarFileName(contentType, asset.fileName),
    contentType,
    byteSize: blob.size,
    blob,
  };
}

export async function uploadAvatarBinary(file: AvatarFile, uploadUrl: string, onProgress: AvatarUploadProgress): Promise<void> {
  // prepareAvatarFile 已取到 Blob，直接复用，避免对本地 URI 二次 fetch。
  const blob = file.blob ?? (await fetchFileBlob(file.uri));
  await uploadBlob(blob, uploadUrl, { 'Content-Type': file.contentType }, onProgress, FAILURE_LABEL, CORS_MESSAGE);
}
