import 'dart:typed_data';

import 'package:dio/dio.dart';

/// @brief Isolated HTTP uploader for presigned object-storage PUT requests.
/// @note Dedicated client with no API interceptors, cookies, or bearer credentials.
class ObjectUploader {
  ObjectUploader({Dio? dio}) : _dio = dio ?? Dio();
  final Dio _dio;

  /// @brief 向预签名对象地址 PUT 上传二进制字节。
  /// @details 透传所需请求头、取消令牌和进度回调；仅允许 HTTPS 或回环 HTTP，拒绝敏感请求头和自动重定向。
  /// @param url 目标预签名上传地址。
  /// @param bytes 待上传的图片字节。
  /// @param requiredHeaders 服务端签发要求的请求头集合。
  /// @param cancelToken 可选取消令牌。
  /// @param onProgress 可选上传进度回调。
  /// @throws FormatException 当上传地址无效或包含被禁止的敏感请求头时抛出。
  Future<void> put({
    required String url,
    required Uint8List bytes,
    required Map<String, String> requiredHeaders,
    CancelToken? cancelToken,
    ProgressCallback? onProgress,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !(uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                ['localhost', '127.0.0.1', '::1'].contains(uri.host))) ||
        requiredHeaders.keys.any(
          (key) => [
            'authorization',
            'cookie',
            'proxy-authorization',
            'host',
          ].contains(key.toLowerCase()),
        )) {
      throw const FormatException('上传地址或请求头不可用');
    }
    await _dio.putUri<void>(
      uri,
      data: bytes,
      cancelToken: cancelToken,
      onSendProgress: onProgress,
      options: Options(
        headers: requiredHeaders,
        followRedirects: false,
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
  }

  /// @brief 关闭上传 Dio 实例并强制终止其未完成请求。
  void close() => _dio.close(force: true);
}
