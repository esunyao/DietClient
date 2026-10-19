import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import 'types.dart';

/// One short-lived flow session. Never reuse this object between logins.
class FlowExecutor {
  FlowExecutor(this.config, {Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..followRedirects = false
      ..validateStatus = ((status) =>
          status != null && status >= 200 && status < 600)
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
  final Completer<Uri> _cancelled = Completer<Uri>();
  bool _closed = false;
  bool _started = false;
  String? _flowId;
  int _redirects = 0;

  Future<Uri> run({
    required Uri authorizationUri,
    required String username,
    required String password,
    Future<bool> Function(AuthentikConsent)? onConsent,
  }) async {
    if (_started || _closed) {
      throw const AuthFailure('disposed', '登录流程已关闭。');
    }
    _started = true;
    try {
      return await Future.any([
        _execute(authorizationUri, username, password, onConsent),
        _cancelled.future,
      ]).timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          _closed = true;
          _cancel.cancel();
          throw const AuthFailure('timeout', '登录超时，请重试。');
        },
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const AuthFailure('cancelled', '登录已取消。');
      }
      throw const AuthFailure('network', '认证服务连接失败，请稍后重试。');
    } on FormatException {
      throw const AuthFailure('invalid_response', '认证服务返回了无法识别的响应。');
    }
  }

  void _check() {
    if (_closed || _cancel.isCancelled) {
      throw const AuthFailure('cancelled', '登录已取消。');
    }
  }

  Future<Uri> _execute(
    Uri authorization,
    String username,
    String password,
    Future<bool> Function(AuthentikConsent)? onConsent,
  ) async {
    _allowed(authorization);
    final next =
        '${authorization.path}${authorization.hasQuery ? '?${authorization.query}' : ''}';
    final query = Uri(
      queryParameters: {...authorization.queryParameters, 'next': next},
    ).query;
    var endpoint = config.baseUri
        .resolve('/api/v3/flows/executor/${config.authenticationFlowSlug}/')
        .replace(queryParameters: {'query': query});
    var target = endpoint;
    Map<String, dynamic>? body;
    var stages = 0;
    var identificationSent = false;
    var passwordSent = false;
    while (true) {
      _check();
      final callback = _isCallback(target);
      if (callback) return target;
      _allowed(target);
      final flowEntry = RegExp(
        r'^/if/flow/([A-Za-z0-9_-]+)/$',
      ).firstMatch(target.path);
      if (flowEntry != null) {
        if (endpoint.path != '/api/v3/flows/executor/${flowEntry.group(1)}/') {
          _flowId = null;
        }
        endpoint = config.baseUri
            .resolve('/api/v3/flows/executor/${flowEntry.group(1)}/')
            .replace(queryParameters: {'query': target.query});
        target = endpoint;
        body = null;
      } else if (target.path.startsWith('/api/v3/flows/executor/')) {
        if (endpoint.path != target.path) _flowId = null;
        endpoint = target;
      }
      final csrfCookies = await _cookies.loadForRequest(target);
      _check();
      final csrf = csrfCookies.where(
        (cookie) => cookie.name == 'authentik_csrf',
      );
      final response = await _dio.requestUri<String>(
        target,
        data: body,
        cancelToken: _cancel,
        options: Options(
          method: body == null ? 'GET' : 'POST',
          headers: {
            'Accept': 'application/json',
            'Origin': config.baseUri.origin,
            'Referer': config.baseUri
                .resolve('/if/flow/${config.authenticationFlowSlug}/')
                .toString(),
            if (_flowId != null) 'x-authentik-id': _flowId,
            if (body != null && csrf.isNotEmpty)
              'X-CSRFToken': csrf.first.value,
          },
          contentType: Headers.jsonContentType,
        ),
      );
      // CookieManager has absorbed all Set-Cookie headers before this returns.
      _check();
      final flowId = response.headers.value('x-authentik-id');
      if (flowId != null && flowId.isNotEmpty) _flowId = flowId;
      final status = response.statusCode!;
      if (status >= 300 && status < 400) {
        if (status != 302 &&
            status != 303 &&
            !(body == null &&
                (status == 301 || status == 307 || status == 308))) {
          throw const AuthFailure('unsafe_redirect', '认证服务返回了不支持的跳转。');
        }
        final location = response.headers.value('location');
        if (location == null || location.isEmpty) {
          throw const AuthFailure('invalid_redirect', '认证跳转缺少目标地址。');
        }
        target = _redirect(target, location);
        body = null; // Never replay a credential POST after a redirect.
        continue;
      }
      if (status < 200 || status >= 300) {
        throw AuthFailure(
          status == 400 ? 'field_error' : 'http_error',
          status == 400 ? '认证信息校验失败，请检查输入。' : '认证服务请求失败。',
        );
      }
      final raw = jsonDecode(response.data ?? '');
      if (raw is! Map<String, dynamic> || raw['component'] is! String) {
        throw const AuthFailure('invalid_response', '认证服务返回了无效的流程组件。');
      }
      if (++stages > 20) {
        throw const AuthFailure('stage_limit', '认证流程步骤过多，请重试。');
      }
      final errors = raw['response_errors'];
      if (errors != null && (errors is! Map || errors.isNotEmpty)) {
        throw const AuthFailure('field_error', '认证信息校验失败，请检查输入。');
      }
      final component = raw['component'] as String;
      body = {'component': component};
      switch (component) {
        case 'xak-flow-redirect':
          final to = raw['to'];
          if (to is! String || to.isEmpty) {
            throw const AuthFailure('invalid_redirect', '认证跳转缺少目标地址。');
          }
          target = _redirect(target, to);
          body = null;
          continue;
        case 'ak-stage-identification':
          if (identificationSent) {
            throw const AuthFailure('field_error', '认证步骤未通过，请检查输入后重新登录。');
          }
          identificationSent = true;
          if (raw['captcha_stage'] != null) {
            throw const AuthFailure(
              'captcha_required',
              '此登录流程需要验证码，当前客户端暂不支持。',
            );
          }
          body['uid_field'] = username;
          if (raw['password_fields'] == true) {
            if (passwordSent) {
              throw const AuthFailure('field_error', '密码步骤未通过，请重新登录。');
            }
            passwordSent = true;
            body['password'] = password;
          }
        case 'ak-stage-password':
          if (passwordSent) {
            throw const AuthFailure('field_error', '密码步骤未通过，请重新登录。');
          }
          passwordSent = true;
          body['password'] = password;
        case 'ak-stage-autosubmit':
        case 'ak-stage-user-login':
          break;
        case 'ak-stage-consent':
          final consent = _consent(raw);
          if (onConsent == null) {
            throw const AuthFailure('consent_required', '请确认应用授权后继续登录。');
          }
          final accepted = await onConsent(consent);
          _check();
          if (!accepted) throw const AuthFailure('consent_denied', '你已取消应用授权。');
          if (raw.containsKey('token')) {
            if (raw['token'] is! String || (raw['token'] as String).isEmpty) {
              throw const AuthFailure('invalid_challenge', '授权步骤格式不受支持。');
            }
            body['token'] = raw['token'];
          }
        case 'ak-stage-access-denied':
          throw const AuthFailure('access_denied', '认证服务拒绝了本次登录。');
        case 'ak-stage-captcha':
          throw const AuthFailure('captcha_required', '此登录流程需要验证码，当前客户端暂不支持。');
        default:
          throw AuthFailure(
            component.startsWith('ak-stage-authenticator-')
                ? 'mfa_required'
                : 'unsupported_challenge',
            component.startsWith('ak-stage-authenticator-')
                ? '此账号需要额外身份验证，当前客户端暂不支持。'
                : '当前客户端不支持此认证步骤。',
          );
      }
      target = endpoint;
    }
  }

  AuthentikConsent _consent(Map<String, dynamic> challenge) {
    final title = challenge['header_text'] ?? challenge['title'];
    if (title is! String) {
      throw const AuthFailure('invalid_challenge', '授权步骤缺少标题。');
    }
    final permissions = <String>[];
    for (final key in ['permissions', 'additional_permissions']) {
      final values = challenge[key];
      if (values == null && key == 'additional_permissions') continue;
      if (values is! List) {
        throw const AuthFailure('invalid_challenge', '授权权限格式不受支持。');
      }
      for (final value in values) {
        if (value is! Map ||
            value['name'] is! String ||
            value['id'] is! String) {
          throw const AuthFailure('invalid_challenge', '授权权限格式不受支持。');
        }
        final name = value['name'] as String;
        if (name.isNotEmpty && !permissions.contains(name)) {
          permissions.add(name);
        }
      }
    }
    return AuthentikConsent(title: title, permissions: permissions);
  }

  Uri _redirect(Uri source, String location) {
    if (++_redirects > 8) {
      throw const AuthFailure('redirect_limit', '认证跳转次数过多，请重试。');
    }
    final uri = source.resolve(location);
    if (!_isCallback(uri)) _allowed(uri);
    return uri;
  }

  bool _isCallback(Uri uri) {
    final expected = config.redirectUri;
    return uri.scheme == expected.scheme &&
        uri.userInfo == expected.userInfo &&
        uri.host == expected.host &&
        uri.port == expected.port &&
        uri.path == expected.path &&
        uri.fragment.isEmpty &&
        expected.queryParameters.entries.every(
          (entry) => uri.queryParameters[entry.key] == entry.value,
        );
  }

  void _allowed(Uri uri) {
    if (uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.scheme != config.baseUri.scheme ||
        uri.host != config.baseUri.host ||
        uri.port != config.baseUri.port ||
        !(uri.path == '/application/o/authorize/' ||
            RegExp(
              r'^/api/v3/flows/executor/[A-Za-z0-9_-]+/$',
            ).hasMatch(uri.path) ||
            RegExp(r'^/if/flow/[A-Za-z0-9_-]+/$').hasMatch(uri.path))) {
      throw const AuthFailure('untrusted_redirect', '认证服务返回了不受信任的地址。');
    }
  }

  void cancel() {
    if (_closed) return;
    _closed = true;
    _cancel.cancel();
    if (_started && !_cancelled.isCompleted) {
      _cancelled.completeError(const AuthFailure('cancelled', '登录已取消。'));
    }
  }

  Future<void> dispose() async {
    cancel();
    _dio.close(force: true);
    await _cookies.deleteAll();
  }
}
