import type { Asset } from 'react-native-image-picker';

import type { ImageContentType } from '../../api/nutriTypes';

export interface CaptureImageFile {
  uri: string;
  fileName: string;
  contentType: ImageContentType;
  byteSize: number;
  capturedAt: string | null;
  blob?: Blob;
}

export interface CaptureImagePreview {
  uri: string;
  imageId: string;
  fileName: string;
  contentType: ImageContentType;
  byteSize: number;
  capturedAt: string | null;
  remote: true;
}

export type CaptureUploadProgress = (percent: number) => void;

const supportedTypes: ImageContentType[] = ['image/jpeg', 'image/png', 'image/webp'];

export function prepareCaptureMimeType(asset: Asset): ImageContentType {
  const type = asset.type?.toLowerCase() === 'image/jpg' ? 'image/jpeg' : asset.type?.toLowerCase();
  if (!type || !supportedTypes.includes(type as ImageContentType))
    throw new Error('请选择 JPG、PNG 或 WebP 格式的图片。');
  return type as ImageContentType;
}

export function makeCaptureFileName(contentType: ImageContentType, sourceName?: string): string {
  const extension =
    contentType === 'image/png' ? 'png' : contentType === 'image/webp' ? 'webp' : 'jpg';
  const safeName = sourceName?.replace(/[^a-zA-Z0-9._-]/g, '_');
  return safeName?.endsWith(`.${extension}`) ? safeName : `meal_${Date.now()}.${extension}`;
}
