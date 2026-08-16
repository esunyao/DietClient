/**
 * TypeScript 使用此文件做跨平台解析；运行时由 .web.ts 替换。
 * 仅 Web 端（.web.ts）会引用本模块，原生打包图不会进入。
 */
export { fetchFileBlob, uploadBlob } from './uploadBlob.web';
export type { UploadFailureLabel, UploadProgress } from './types';
