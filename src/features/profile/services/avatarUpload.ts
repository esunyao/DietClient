/**
 * TypeScript 使用此文件做跨平台解析；运行时由 .native.ts 或 .web.ts 替换。
 * 该兜底不会在 React Native/Web bundler 中执行。
 */
export { prepareAvatarFile, uploadAvatarBinary } from './avatarUpload.native';
