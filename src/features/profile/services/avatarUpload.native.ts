import ReactNativeBlobUtil from 'react-native-blob-util';
import type { Asset } from 'react-native-image-picker';

import { assertAvatarSize, makeAvatarFileName, resolveAvatarMimeType, type AvatarFile, type AvatarUploadProgress } from './avatarUpload.types';

/** 原生端通过文件流 PUT 预签名地址，避免把整张图片读入 JS 内存。 */
export async function prepareAvatarFile(asset: Asset): Promise<AvatarFile> {
  if (!asset.uri) {
    throw new Error('没有获得图片文件，请重新选择。');
  }

  const contentType = resolveAvatarMimeType(asset);
  const byteSize = asset.fileSize || 0;
  assertAvatarSize(byteSize);
  return {
    uri: asset.originalPath || asset.uri,
    fileName: makeAvatarFileName(contentType, asset.fileName),
    contentType,
    byteSize,
  };
}

export async function uploadAvatarBinary(file: AvatarFile, uploadUrl: string, onProgress: AvatarUploadProgress): Promise<void> {
  const localPath = file.uri.startsWith('file://') ? file.uri.slice('file://'.length) : file.uri;
  const response = await ReactNativeBlobUtil
    .fetch('PUT', uploadUrl, { 'Content-Type': file.contentType }, ReactNativeBlobUtil.wrap(localPath))
    .uploadProgress({ interval: 120 }, (sent, total) => onProgress(total > 0 ? Math.round((sent / total) * 100) : 0));

  const status = response.info().status;
  if (status < 200 || status >= 300) {
    throw new Error(`头像文件上传失败（HTTP ${status}）。`);
  }
  onProgress(100);
}
