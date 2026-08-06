import type { Asset } from 'react-native-image-picker';

import { assertAvatarSize, makeAvatarFileName, resolveAvatarMimeType, type AvatarFile, type AvatarUploadProgress } from './avatarUpload.types';

/** Web 端图片选择器提供 data URI / blob URL；转成 Blob 后才能正确 PUT 到对象存储。 */
export async function prepareAvatarFile(asset: Asset): Promise<AvatarFile> {
  if (!asset.uri) {
    throw new Error('没有获得图片文件，请重新选择。');
  }

  const blob = await fetch(asset.uri).then(async response => {
    if (!response.ok) {
      throw new Error('无法读取所选图片，请重新选择。');
    }
    return response.blob();
  });
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
  const blob = file.blob ?? (await fetch(file.uri).then(response => response.blob()));

  await new Promise<void>((resolve, reject) => {
    const request = new XMLHttpRequest();
    request.open('PUT', uploadUrl);
    request.setRequestHeader('Content-Type', file.contentType);
    request.upload.onprogress = event => {
      if (event.lengthComputable) {
        onProgress(Math.round((event.loaded / event.total) * 100));
      }
    };
    request.onerror = () => reject(new Error('上传被浏览器跨域策略或网络拦截，请确认对象存储已开启 CORS 并允许本机地址访问。'));
    request.onload = () => {
      if (request.status >= 200 && request.status < 300) {
        onProgress(100);
        resolve();
      } else {
        reject(new Error(`头像文件上传失败（HTTP ${request.status}）。`));
      }
    };
    request.send(blob);
  });
}
