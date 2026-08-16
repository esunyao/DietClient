/**
 * TypeScript 使用此文件做跨平台解析；运行时由 .native.ts 替换。
 * 仅原生端（.native.ts）会引用本模块，Web 打包图不会进入。
 */
export { uploadFileBinary } from './uploadFile.native';
export type { UploadFailureLabel, UploadProgress } from './types';
