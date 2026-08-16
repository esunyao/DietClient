import ReactNativeBlobUtil from 'react-native-blob-util';

/** 原生系统 URI 统一转为可供文件流读取的缓存路径。 */
export async function resolveLocalPath(uri: string, extension: string): Promise<string> {
  if (uri.startsWith('file://')) {
    return uri.slice('file://'.length);
  }

  const response = await ReactNativeBlobUtil.config({ fileCache: true, appendExt: extension }).fetch('GET', uri);
  const path = response.path();
  return path.startsWith('file://') ? path.slice('file://'.length) : path;
}

/** 读取文件字节数；读取失败返回 0（无法校验大小时跳过大小校验，避免误报）。 */
export async function readFileSize(localPath: string): Promise<number> {
  try {
    const stat = await ReactNativeBlobUtil.fs.stat(localPath);
    return Number(stat.size) || 0;
  } catch {
    return 0;
  }
}
