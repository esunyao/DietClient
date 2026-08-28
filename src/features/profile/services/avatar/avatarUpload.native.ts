import type { Asset } from 'react-native-image-picker';

import {
  assertAvatarSize,
  makeAvatarFileName,
  resolveAvatarMimeType,
  type AvatarFile,
  type AvatarUploadProgress,
} from './avatarUpload.types';
import { resolveLocalPath, readFileSize } from '../../../../shared/upload/nativeFile';
import { uploadFileBinary } from '../../../../shared/upload/uploadFile';

const FAILURE_LABEL = '头像文件上传失败';

/** 原生端通过文件流 PUT 预签名地址，避免把整张图片读入 JS 内存。 */
export async function prepareAvatarFile(asset: Asset): Promise<AvatarFile> {
  if (!asset.uri) {
    throw new Error('没有获得图片文件，请重新选择。');
  }

  const contentType = resolveAvatarMimeType(asset);
  const extension =
    contentType === 'image/png' ? 'png' : contentType === 'image/webp' ? 'webp' : 'jpg';
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

export async function uploadAvatarBinary(
  file: AvatarFile,
  uploadUrl: string,
  onProgress: AvatarUploadProgress,
): Promise<void> {
  await uploadFileBinary(
    file.uri,
    uploadUrl,
    { 'Content-Type': file.contentType },
    onProgress,
    FAILURE_LABEL,
  );
}
