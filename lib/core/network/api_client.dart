import 'package:dio/dio.dart';
import 'package:diet_auth/diet_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../config/ui_preview_config.dart';
import '../session/session_controller.dart';
import 'lossless_json.dart';

/// 业务 API 请求失败异常，保留面向用户的本地安全提示、HTTP 状态码与业务信封 `code`。
class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.status, this.code});

  final String message;
  final int? status;
  final int? code;

  @override
  String toString() => message;
}

/// 业务 API 基址配置 Provider。
final apiConfigProvider = Provider<ApiConfig>(
  (ref) => ApiConfig(const String.fromEnvironment('API_BASE_URL')),
);

/// 业务请求底层 Dio 工厂 Provider（便于离线测试替换适配器）。
final apiDioFactoryProvider = Provider<Dio Function()>(
  (ref) =>
      () => Dio(BaseOptions(connectTimeout: const Duration(seconds: 30))),
);

/// 当前登录会话的业务 API 客户端 Provider；预览或未登录返回 `null`，按登录代次隔离。
final apiClientProvider = Provider<ApiClient?>((ref) {
  final epoch = ref.watch(sessionEpochProvider);
  final present = ref.watch(sessionProvider.select((value) => value != null));
  final session = ref.read(sessionProvider);
  if (ref.watch(uiPreviewProvider) || !present) return null;
  final client = ApiClient(
    config: ref.watch(apiConfigProvider),
    dio: ref.watch(apiDioFactoryProvider)(),
    session: session!,
    isCurrent: () => ref.mounted && ref.read(sessionEpochProvider) == epoch,
    freshToken: ({bool force = false}) =>
        ref.read(sessionProvider.notifier).ensureFreshAccessToken(force: force),
    currentAccessToken: () =>
        ref.mounted ? ref.read(sessionProvider)?.accessToken : null,
    onUnauthorized: () {
      if (ref.mounted && ref.read(sessionEpochProvider) == epoch) {
        ref.read(sessionProvider.notifier).clear();
      }
    },
  );
  ref.onDispose(client.close);
  return client;
});

/// 业务 HTTP 薄客户端，负责路径白名单校验、Bearer 鉴权、长整型 ID 保护与 GET 401 续期重试。
class ApiClient {
  ApiClient({
    required this.config,
    required this.session,
    required this.isCurrent,
    required this.onUnauthorized,
    Dio? dio,
    this.freshToken,
    this.currentAccessToken,
  }) : _dio =
           dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 30)));

  static final RegExp _profilePathPattern = RegExp(
    r'^v1/(users/self(?:/[a-z-]+(?:/[0-9]+)?)?|files/avatar(?:/(presign|confirm))?)$',
  );
  static final RegExp _nutriPathPattern = RegExp(
    r'^v1/nutri/(capture-policy|capture-sessions(?:/drafts|/[0-9a-fA-F-]{36}(?:/(?:images/presign|images/[0-9]+(?:/confirm)?|submit|retry))?)?|meals(?:/[0-9]+)?|summaries/(?:daily|daily-trend))$',
  );

  final ApiConfig config;
  final OidcSession session;
  final bool Function() isCurrent;
  final void Function() onUnauthorized;
  final Dio _dio;
  final Future<String> Function({bool force})? freshToken;
  final String? Function()? currentAccessToken;

  /// 关闭底层 Dio 并强制终止未完成请求。
  void close() => _dio.close(force: true);

  /// 请求允许范围内的资料或膳食相对路径并解包业务信封 `data`；GET 在 401 时最多续期重试一次。
  Future<Object?> request(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    _validateRequestScope(path, headers);
    if (!isCurrent() || (freshToken == null && !hasActiveSession(session))) {
      throw const ApiFailure('请重新登录');
    }
    return _sendRequest(
      path: path,
      method: method,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      cancelToken: cancelToken,
      retried: false,
      forceRefresh: false,
    );
  }

  void _validateRequestScope(String path, Map<String, String>? headers) {
    final allowedPath =
        _profilePathPattern.hasMatch(path) || _nutriPathPattern.hasMatch(path);
    final hasDisallowedHeader =
        headers?.keys.any((key) => key.toLowerCase() != 'x-idempotency-key') ??
        false;
    if (!allowedPath || hasDisallowedHeader) {
      throw const ApiFailure('请求路径不可用');
    }
  }

  Future<Object?> _sendRequest({
    required String path,
    required String method,
    required Object? data,
    required Map<String, dynamic>? queryParameters,
    required Map<String, String>? headers,
    required CancelToken? cancelToken,
    required bool retried,
    required bool forceRefresh,
  }) async {
    String? usedToken;
    try {
      final token = freshToken == null
          ? session.accessToken
          : await freshToken!(force: forceRefresh);
      usedToken = token;
      if (!isCurrent()) throw const ApiFailure('会话已更换');
      final response = await _dio.request<String>(
        config.baseUrl.resolve(path).toString(),
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          responseType: ResponseType.plain,
          followRedirects: false,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          headers: {
            ...?headers,
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      if (!isCurrent()) throw const ApiFailure('会话已更换');
      final envelope =
          decodeApiJson(response.data ?? '') as Map<String, dynamic>;
      final code = envelope['code'];
      if (code != 200 && code != 201 && code != 202 && code != 204) {
        throw ApiFailure(
          _failureMessage(code is int ? code : null),
          status: response.statusCode,
          code: code is int ? code : null,
        );
      }
      return envelope['data'];
    } on DioException catch (error) {
      if (!isCurrent()) throw const ApiFailure('会话已更换');
      final status = error.response?.statusCode;
      if (status == 401) {
        final retryResult = await _handleUnauthorized(
          path: path,
          method: method,
          data: data,
          queryParameters: queryParameters,
          headers: headers,
          cancelToken: cancelToken,
          retried: retried,
          usedToken: usedToken,
        );
        if (retryResult.$1) return retryResult.$2;
      }
      throw ApiFailure(
        status == null
            ? _transportMessage(error.type)
            : _failureMessage(status),
        status: status,
      );
    } on ApiFailure catch (error) {
      if (error.code == 401) {
        final retryResult = await _handleUnauthorized(
          path: path,
          method: method,
          data: data,
          queryParameters: queryParameters,
          headers: headers,
          cancelToken: cancelToken,
          retried: retried,
          usedToken: usedToken,
        );
        if (retryResult.$1) return retryResult.$2;
      }
      rethrow;
    } catch (_) {
      throw const ApiFailure('服务响应不可用，请重试');
    }
  }

  Future<(bool, Object?)> _handleUnauthorized({
    required String path,
    required String method,
    required Object? data,
    required Map<String, dynamic>? queryParameters,
    required Map<String, String>? headers,
    required CancelToken? cancelToken,
    required bool retried,
    required String? usedToken,
  }) async {
    if (!isCurrent()) return (false, null);
    if (method.toUpperCase() == 'GET' && !retried && freshToken != null) {
      final current = await freshToken!(force: false);
      final value = await _sendRequest(
        path: path,
        method: method,
        data: data,
        queryParameters: queryParameters,
        headers: headers,
        cancelToken: cancelToken,
        retried: true,
        forceRefresh: current == usedToken,
      );
      return (true, value);
    }
    final currentToken = currentAccessToken?.call();
    // 迟到的旧令牌 401 不应清除已经完成轮换的新令牌。
    if (currentToken == null || currentToken == usedToken) {
      onUnauthorized();
    }
    return (false, null);
  }
}

String _failureMessage(int? code) => switch (code ?? 0) {
  400 || 422 => '提交内容不符合要求，请检查填写的信息后重试',
  401 => '登录已失效，请重新登录',
  403 => '当前账号无权进行此操作，请确认登录账号或联系管理员',
  404 => '内容不存在或已被删除，请刷新页面后重试',
  408 || 504 => '服务响应超时，请稍后重试',
  409 => '内容状态已变化或记录已存在，请刷新查看后再操作',
  410 => '内容已过期，请刷新页面或重新创建',
  413 => '提交的文件过大，请选择较小的图片后重试',
  415 => '文件格式不受支持，请选择 JPEG、PNG 或 WebP 图片',
  429 => '操作过于频繁，请稍后再试',
  >= 500 && <= 599 => '服务暂时不可用，请稍后重试',
  _ => '操作未完成，请稍后重试',
};

String _transportMessage(DioExceptionType type) => switch (type) {
  DioExceptionType.cancel => '请求已取消',
  DioExceptionType.connectionTimeout ||
  DioExceptionType.sendTimeout ||
  DioExceptionType.receiveTimeout => '网络请求超时，请检查网络后重试',
  DioExceptionType.badCertificate => '无法验证服务的安全连接，请检查设备时间或联系管理员',
  _ => '无法连接服务，请检查网络后重试',
};
