/**
 * 公有上传管理类：统一封装“本地文件解析 → 预签名地址上传”链路。
 * - nativeFile / uploadFile 仅原生端使用（ReactNativeBlobUtil 文件流）。
 * - uploadBlob 仅 Web 端使用（Blob + XMLHttpRequest）。
 * 各业务（餐食图片、头像）只保留自己的格式与大小校验，上传机制集中于此。
 */
export * from './types';
