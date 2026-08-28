import type { Asset } from 'react-native-image-picker';

export const MAX_AVATAR_BYTES = 5 * 1024 * 1024;

export type AvatarMimeType = 'image/jpeg' | 'image/png' | 'image/webp';

export interface AvatarFile {
  uri: string;
  fileName: string;
  contentType: AvatarMimeType;
  byteSize: number;
  /** 仅 Web 端填充：prepare 阶段已取到的 Blob，供 PUT 时复用，避免二次 fetch。原生端忽略。 */
  blob?: Blob;
}

export type AvatarUploadProgress = (percent: number) => void;

const supportedTypes: AvatarMimeType[] = ['image/jpeg', 'image/png', 'image/webp'];

export function resolveAvatarMimeType(asset: Asset): AvatarMimeType {
  const contentType =
    asset.type?.toLowerCase() === 'image/jpg' ? 'image/jpeg' : asset.type?.toLowerCase();
  if (!contentType || !supportedTypes.includes(contentType as AvatarMimeType)) {
    throw new Error('请选择 JPG、PNG 或 WebP 格式，且不超过 5 MB 的图片。');
  }
  return contentType as AvatarMimeType;
}

export function assertAvatarSize(byteSize: number): void {
  if (!Number.isFinite(byteSize) || byteSize <= 0) {
    throw new Error('无法读取图片大小，请重新选择一张图片。');
  }
  if (byteSize > MAX_AVATAR_BYTES) {
    throw new Error('头像图片不能超过 5 MB，请选择更小的图片。');
  }
}

export function makeAvatarFileName(contentType: AvatarMimeType, sourceName?: string): string {
  const extension =
    contentType === 'image/png' ? 'png' : contentType === 'image/webp' ? 'webp' : 'jpg';
  const safeName = sourceName?.replace(/[^a-zA-Z0-9._-]/g, '_');
  return safeName?.endsWith(`.${extension}`) ? safeName : `avatar_${Date.now()}.${extension}`;
}
