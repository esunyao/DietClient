import ReactNativeBlobUtil from 'react-native-blob-util';
import type { Asset } from 'react-native-image-picker';

import { assertAvatarSize, makeAvatarFileName, resolveAvatarMimeType, type AvatarFile, type AvatarUploadProgress } from './avatarUpload.types';

/** 把 image-picker 返回的 uri 归一为 RNFetchBlob 可读取的文件系统路径。
 *  file:// 去掉协议前缀即可；content://（Android）与 ph://（iOS）属于系统解析协议，
 *  无法被 wrap 直接读取，需先通过 RNFetchBlob 落盘到应用缓存再使用。 */
async function resolveLocalPath(uri: string, extension: string): Promise<string> {
  if (uri.startsWith('file://')) {
    return uri.slice('file://'.length);
  }

  const response = await ReactNativeBlobUtil.config({ fileCache: true, appendExt: extension }).fetch('GET', uri);
  const path = response.path();
  return path.startsWith('file://') ? path.slice('file://'.length) : path;
}

/** 读取文件字节数；读取失败返回 0（无法校验大小时跳过 5MB 校验，避免误报）。 */
async function readFileSize(localPath: string): Promise<number> {
  try {
    const stat = await ReactNativeBlobUtil.fs.stat(localPath);
    return Number(stat.size) || 0;
  } catch {
    return 0;
  }
}

/** 原生端通过文件流 PUT 预签名地址，避免把整张图片读入 JS 内存。 */
export async function prepareAvatarFile(asset: Asset): Promise<AvatarFile> {
  if (!asset.uri) {
    throw new Error('没有获得图片文件，请重新选择。');
  }

  const contentType = resolveAvatarMimeType(asset);
  const extension = contentType === 'image/png' ? 'png' : contentType === 'image/webp' ? 'webp' : 'jpg';
  const localPath = await resolveLocalPath(asset.uri, extension);
  const byteSize = await readFileSize(localPath);

  if (byteSize > 0) {
    assertAvatarSize(byteSize);
  }

  return {
    uri: localPath,
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
