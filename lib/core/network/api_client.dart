import 'package:dio/dio.dart';
import 'package:diet_auth/diet_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../config/ui_preview_config.dart';
import '../session/session_controller.dart';
import 'lossless_json.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

final apiConfigProvider = Provider<ApiConfig>(
  (ref) => ApiConfig(const String.fromEnvironment('API_BASE_URL')),
);
final apiDioFactoryProvider = Provider<Dio Function()>(
  (ref) =>
      () => Dio(BaseOptions(connectTimeout: const Duration(seconds: 30))),
);
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
    onUnauthorized: () {
      if (ref.mounted && ref.read(sessionEpochProvider) == epoch) {
        ref.read(sessionProvider.notifier).clear();
      }
    },
  );
  ref.onDispose(client.close);
  return client;
});

class ApiClient {
  ApiClient({
    required this.config,
    required this.session,
    required this.isCurrent,
    required this.onUnauthorized,
    Dio? dio,
    this.freshToken,
  }) : _dio =
           dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 30)));
  final ApiConfig config;
  final OidcSession session;
  final bool Function() isCurrent;
  final void Function() onUnauthorized;
  final Dio _dio;
  final Future<String> Function({bool force})? freshToken;
  void close() => _dio.close(force: true);
  Future<Object?> request(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    final profilePath = RegExp(
      r'^v1/(users/self(?:/[a-z-]+(?:/[0-9]+)?)?|files/avatar(?:/(presign|confirm))?)$',
    ).hasMatch(path);
    final nutriPath = RegExp(
      r'^v1/nutri/(capture-policy|capture-sessions(?:/drafts|/[0-9a-fA-F-]{36}(?:/(?:images/presign|images/[0-9]+(?:/confirm)?|submit|retry))?)?|meals(?:/[0-9]+)?|summaries/(?:daily|daily-trend))$',
    ).hasMatch(path);
    if ((!profilePath && !nutriPath) ||
        (headers?.keys.any((key) => key.toLowerCase() != 'x-idempotency-key') ??
            false)) {
      throw const ApiFailure('请求路径不可用');
    }
    if (!isCurrent() || (freshToken == null && !hasActiveSession(session))) {
      throw const ApiFailure('请重新登录');
    }
    Future<Object?> send(bool retry, {bool forceRefresh = false}) async {
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
        if (envelope['code'] != 200 &&
            envelope['code'] != 201 &&
            envelope['code'] != 202 &&
            envelope['code'] != 204) {
          throw const ApiFailure('操作未完成，请重试');
        }
        return envelope['data'];
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 401 && isCurrent()) {
          if (method.toUpperCase() == 'GET' && !retry && freshToken != null) {
            final current = await freshToken!(force: false);
            return send(true, forceRefresh: current == usedToken);
          }
          onUnauthorized();
        }
        throw ApiFailure(
          status == 401 ? '登录已失效，请重新登录' : '请求失败，请检查网络后重试',
          status: status,
        );
      } on ApiFailure {
        rethrow;
      } catch (_) {
        throw const ApiFailure('服务响应不可用，请重试');
      }
    }

    return send(false);
  }
}
