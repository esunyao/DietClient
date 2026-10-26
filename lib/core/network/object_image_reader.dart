import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'api_client.dart';

/// Object GETs never share API authentication, cookies, or interceptors.
class ObjectImageReader {
  ObjectImageReader({HttpClientAdapter? adapter})
    : _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 30))) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  static const maxBytes = 10 * 1024 * 1024;
  final Dio _dio;

  Future<Uint8List> read({
    required String url,
    CancelToken? cancelToken,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !(uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                ['localhost', '127.0.0.1', '::1'].contains(uri.host)))) {
      throw const ApiFailure('照片地址不可用，请刷新后重试');
    }
    ResponseBody? body;
    var streamStarted = false;
    final requestCancel = CancelToken();
    if (cancelToken != null) {
      cancelToken.whenCancel.then((_) => requestCancel.cancel());
    }
    try {
      _checkCancelled(cancelToken);
      final response = await _dio.getUri<ResponseBody>(
        uri,
        cancelToken: requestCancel,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (_) => true,
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Accept': 'image/jpeg,image/png,image/webp'},
        ),
      );
      body = response.data;
      final status = response.statusCode;
      if (status != 200) {
        throw ApiFailure(_statusMessage(status), status: status);
      }
      final type = response.headers
          .value('content-type')
          ?.split(';')
          .first
          .trim();
      if (!const ['image/jpeg', 'image/png', 'image/webp'].contains(type)) {
        throw const ApiFailure('照片格式不可用，请刷新后重试');
      }
      final length = int.tryParse(
        response.headers.value('content-length') ?? '',
      );
      if (length != null && length > maxBytes) {
        throw const ApiFailure('照片超过 10 MiB，无法显示');
      }
      if (body == null) throw const ApiFailure('照片内容为空，请重试');
      final bytes = BytesBuilder(copy: false);
      streamStarted = true;
      await for (final chunk in body.stream) {
        _checkCancelled(cancelToken);
        if (bytes.length + chunk.length > maxBytes) {
          throw const ApiFailure('照片超过 10 MiB，无法显示');
        }
        bytes.add(chunk);
      }
      _checkCancelled(cancelToken);
      if (bytes.isEmpty) throw const ApiFailure('照片内容为空，请重试');
      return bytes.takeBytes();
    } on DioException catch (error) {
      throw ApiFailure(switch (error.type) {
        DioExceptionType.cancel => '照片读取已取消',
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => '照片读取超时，请检查网络后重试',
        DioExceptionType.badCertificate => '无法验证照片的安全连接',
        _ => '照片读取失败，请检查网络后重试',
      });
    } on ApiFailure {
      rethrow;
    } catch (_) {
      throw const ApiFailure('照片响应不可用，请稍后重试');
    } finally {
      // Cancel the transport too: abandoning a buffered stream alone need not
      // stop the adapter's upstream subscription.
      requestCancel.cancel();
      await requestCancel.whenCancel;
      if (body != null && !streamStarted) {
        await body.stream.listen((_) {}, onError: (Object _) {}).cancel();
      }
    }
  }

  void close() => _dio.close(force: true);
}

void _checkCancelled(CancelToken? cancel) {
  if (cancel?.isCancelled == true) throw cancel!.cancelError!;
}

String _statusMessage(int? status) => switch (status ?? 0) {
  401 || 403 => '照片链接已失效，请重试',
  404 || 410 => '照片不存在或已被删除',
  >= 300 && < 400 => '照片地址发生跳转，请刷新后重试',
  429 => '照片读取过于频繁，请稍后重试',
  _ => '照片服务暂时不可用，请稍后重试',
};
