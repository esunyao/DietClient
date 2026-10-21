import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'types.dart';

/// One isolated enrollment/resend attempt, with no redirects or token exchange.
class AuxiliaryFlowExecutor {
  AuxiliaryFlowExecutor(this.config, {Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..followRedirects = false
      ..validateStatus = ((s) => s != null && s >= 200 && s < 600)
      ..responseType = ResponseType.plain
      ..connectTimeout = const Duration(seconds: 20)
      ..sendTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(seconds: 30);
    _dio.interceptors.add(CookieManager(_cookies));
  }
  final AuthentikConfig config;
  final Dio _dio;
  final CookieJar _cookies = CookieJar();
  final CancelToken _cancel = CancelToken();
  bool _started = false;

  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
    String displayName = '',
  }) => _run(config.enrollmentFlowSlug, {
    'username': username.trim(),
    'email': email.trim(),
    'password': password,
    'password-repeat': confirmPassword,
    'nickname': displayName.trim().isEmpty
        ? username.trim()
        : displayName.trim(),
  });
  Future<void> resend(String email) =>
      _run(config.emailVerificationResendFlowSlug, {'email': email.trim()});

  Future<void> _run(String? slug, Map<String, String> values) async {
    if (_started) throw const AuthFailure('busy', '此流程已经开始，请勿重复提交。');
    if (_cancel.isCancelled) throw const AuthFailure('cancelled', '操作已取消。');
    if (slug == null || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(slug)) {
      throw const AuthFailure('configuration', '未配置有效的注册或邮件重发流程。');
    }
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(values['email'] ?? '')) {
      throw AuthFieldFailure({'email': '请输入有效的邮箱地址'});
    }
    if (values.containsKey('password') &&
        (values['username']!.isEmpty ||
            values['password']!.isEmpty ||
            values['password'] != values['password-repeat'])) {
      throw const AuthFailure('credentials_required', '请完整填写注册信息并确认密码一致。');
    }
    _started = true;
    final endpoint = config.baseUri.resolve('/api/v3/flows/executor/$slug/');
    Map<String, dynamic>? body;
    String? flowId;
    final seen = <String>{};
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    try {
      for (var step = 0; step < 12; step++) {
        if (_cancel.isCancelled) throw const AuthFailure('cancelled', '操作已取消。');
        if (DateTime.now().isAfter(deadline)) {
          throw const AuthFailure('timeout', '流程超时，请先检查验证邮件，避免重复注册。');
        }
        final cookies = await _cookies.loadForRequest(endpoint);
        final csrf = cookies.where((c) => c.name == 'authentik_csrf');
        final response = await _dio.requestUri<String>(
          endpoint,
          data: body,
          cancelToken: _cancel,
          options: Options(
            method: body == null ? 'GET' : 'POST',
            contentType: Headers.jsonContentType,
            headers: {
              'Accept': 'application/json',
              'Origin': config.baseUri.origin,
              'Referer': config.baseUri.resolve('/if/flow/$slug/').toString(),
              'x-authentik-id': ?flowId,
              if (body != null && csrf.isNotEmpty)
                'X-CSRFToken': csrf.first.value,
            },
          ),
        );
        if (_cancel.isCancelled) throw const AuthFailure('cancelled', '操作已取消。');
        flowId = response.headers.value('x-authentik-id') ?? flowId;
        final status = response.statusCode!;
        if (status >= 300 && status < 400) {
          throw const AuthFailure(
            'unexpected_redirect',
            '流程返回跳转，无法确认邮件状态，请先检查邮箱。',
          );
        }
        final raw = jsonDecode(response.data ?? '');
        if (raw is! Map<String, dynamic> || raw['component'] is! String) {
          throw const FormatException();
        }
        final errors = raw['response_errors'];
        if (errors != null && (errors is! Map || errors.isNotEmpty)) {
          final fields = <String, String>{};
          if (errors is Map) {
            for (final entry in errors.entries) {
              final items = entry.value;
              if (items is List) {
                final messages = items
                    .whereType<Map>()
                    .map((e) => e['string'])
                    .whereType<String>()
                    .where((e) => e.isNotEmpty);
                if (messages.isNotEmpty) {
                  fields[entry.key.toString()] = messages.join('；');
                }
              }
            }
          }
          throw AuthFieldFailure(fields);
        }
        if (status < 200 || status >= 300) {
          throw const AuthFailure('http_error', '认证服务未受理请求，请稍后重试。');
        }
        final component = raw['component'] as String;
        final info = raw['flow_info'];
        if (info is Map &&
            info['messages'] is List &&
            (info['messages'] as List).whereType<Map>().any(
              (m) => m['level'] == 'error',
            )) {
          throw const AuthFailure('email_rejected', '邮件请求未被受理，请稍后重试。');
        }
        if (component == 'ak-stage-email') {
          // EmailChallenge has no email field (authentik public schema).
          // Acceptance does not reveal whether this address exists.
          return;
        }
        body = {'component': component};
        switch (component) {
          case 'ak-stage-prompt':
            final fields = raw['fields'];
            if (fields is! List || fields.isEmpty) {
              throw const FormatException();
            }
            final names = <String>[];
            for (final field in fields) {
              if (field is! Map || field['field_key'] is! String) {
                throw const FormatException();
              }
              final key = field['field_key'] as String;
              names.add(key);
              final mapped = switch (key) {
                'name' || 'display_name' => 'nickname',
                'password_repeat' => 'password-repeat',
                _ => key,
              };
              if (!values.containsKey(mapped)) {
                throw const AuthFailure(
                  'unsupported_challenge',
                  '注册表单包含当前客户端不支持的字段。',
                );
              }
              body[key] = values[mapped];
            }
            names.sort();
            if (!seen.add('$component:${names.join(",")}')) {
              throw const AuthFailure('no_progress', '流程未继续，请先检查验证邮件，避免重复注册。');
            }
          case 'ak-stage-identification':
            if (!seen.add(component)) {
              throw const AuthFailure('no_progress', '流程未继续，请先检查邮箱。');
            }
            if (raw['captcha_stage'] != null ||
                raw['password_fields'] == true) {
              throw const AuthFailure(
                'unsupported_challenge',
                '邮件重发流程需要不支持的验证。',
              );
            }
            body['uid_field'] = values['email'];
          case 'ak-stage-autosubmit':
            if (!seen.add(component)) {
              throw const AuthFailure('no_progress', '流程未继续，请先检查邮箱。');
            }
          default:
            throw const AuthFailure(
              'unsupported_challenge',
              '当前客户端不支持此注册或邮件验证步骤，请联系管理员。',
            );
        }
      }
      throw const AuthFailure('stage_limit', '流程步骤过多，请先检查邮箱。');
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw const AuthFailure('cancelled', '操作已取消。');
      }
      throw const AuthFailure(
        'network_uncertain',
        '未能确认结果，请先检查验证邮件，避免重复提交相同账号。',
      );
    } on FormatException {
      throw const AuthFailure('invalid_response', '邮件流程响应格式无效，无法确认结果，请先检查邮箱。');
    }
  }

  void cancel() => _cancel.cancel();
  Future<void> dispose() async {
    cancel();
    _dio.close(force: true);
    await _cookies.deleteAll();
  }
}
