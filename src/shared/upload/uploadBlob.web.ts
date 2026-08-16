import type { UploadFailureLabel, UploadProgress } from './types';

/** 把本地 URI（data: / blob: / http:）读成 Blob，供上传复用，避免二次 fetch。 */
export async function fetchFileBlob(uri: string): Promise<Blob> {
  const response = await fetch(uri);
  if (!response.ok) {
    throw new Error('无法读取所选图片，请重新选择。');
  }
  return response.blob();
}

/** Web 端通过 XMLHttpRequest 将 Blob PUT 到预签名地址。 */
export async function uploadBlob(
  blob: Blob,
  uploadUrl: string,
  headers: Record<string, string>,
  onProgress: UploadProgress,
  failureLabel: UploadFailureLabel,
  corsMessage: string,
): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    const request = new XMLHttpRequest();
    request.open('PUT', uploadUrl);
    Object.entries({ ...headers, 'Content-Type': headers['Content-Type'] }).forEach(([name, value]) => request.setRequestHeader(name, value));
    request.upload.onprogress = event => {
      if (event.lengthComputable) {
        onProgress(Math.round((event.loaded / event.total) * 100));
      }
    };
    request.onerror = () => reject(new Error(corsMessage));
    request.onload = () => {
      if (request.status >= 200 && request.status < 300) {
        onProgress(100);
        resolve();
      } else {
        reject(new Error(`${failureLabel}（HTTP ${request.status}）。`));
      }
    };
    request.send(blob);
  });
}
