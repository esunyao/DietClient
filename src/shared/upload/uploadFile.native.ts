import ReactNativeBlobUtil from 'react-native-blob-util';

import type { UploadFailureLabel, UploadProgress } from './types';

/** 原生端通过文件流 PUT 预签名地址，避免把整张文件读入 JS 内存。 */
export async function uploadFileBinary(
  localPath: string,
  uploadUrl: string,
  headers: Record<string, string>,
  onProgress: UploadProgress,
  failureLabel: UploadFailureLabel,
): Promise<void> {
  const response = await ReactNativeBlobUtil
    .fetch('PUT', uploadUrl, { ...headers, 'Content-Type': headers['Content-Type'] }, ReactNativeBlobUtil.wrap(localPath))
    .uploadProgress({ interval: 120 }, (sent, total) => onProgress(total > 0 ? Math.round((sent / total) * 100) : 0));

  const status = response.info().status;
  if (status < 200 || status >= 300) {
    throw new Error(`${failureLabel}（HTTP ${status}）。`);
  }
  onProgress(100);
}
