import 'package:diet_oidc/diet_oidc.dart';

import 'flow_stub.dart' if (dart.library.io) 'flow_native.dart';
import 'types.dart';

const _isWeb = bool.fromEnvironment('dart.library.js_interop');

/// Authentik 认证门面客户端，组合通用 OIDC 与原生 Flow Executor。
class AuthentikAuthClient {
  /// 使用 [config] 初始化认证客户端。
  AuthentikAuthClient(this.config)
    : _oidc = OidcClient(
        OidcConfig(
          discoveryUri: config.discoveryUri,
          clientId: config.clientId,
          redirectUri: _isWeb ? config.webRedirectUri : config.redirectUri,
          scopes: config.scopes,
        ),
      );

  final AuthentikConfig config;
  final OidcClient _oidc;
  FlowExecutor? _flow;
  OidcTransaction? _transaction;
  int _generation = 0;
  bool _disposed = false;
  bool _busy = false;

  void _start() {
    if (_disposed) throw const AuthFailure('disposed', '登录客户端已关闭。');
    if (_busy) throw const AuthFailure('busy', '登录正在进行中。');
    _busy = true;
  }

  /// 在原生平台执行账号密码认证流程及可选应用授权确认，完成后返回 OIDC 会话。
  Future<OidcSession> signInWithPassword({
    required String username,
    required String password,
    Future<bool> Function(AuthentikConsent)? onConsent,
  }) async {
    _start();
    final generation = _generation;
    try {
      if (_isWeb) {
        throw const AuthFailure('unsupported_platform', '网页端请使用弹窗登录。');
      }
      if (username.trim().isEmpty || password.isEmpty) {
        throw const AuthFailure('credentials_required', '请输入账号和密码。');
      }
      final transaction = await _oidc.beginAuthorization();
      _check(generation);
      _transaction = transaction;
      final flow = FlowExecutor(config);
      _flow = flow;
      final callback = await flow.run(
        authorizationUri: transaction.authorizationUri,
        username: username.trim(),
        password: password,
        onConsent: onConsent,
      );
      _check(generation);
      final session = await _oidc.completeAuthorization(transaction, callback);
      _check(generation);
      return session;
    } on OidcFailure catch (error) {
      throw AuthFailure(error.code, error.message);
    } finally {
      final transaction = _transaction;
      if (transaction != null) _oidc.cancel(transaction);
      _transaction = null;
      await _flow?.dispose();
      _flow = null;
      _busy = false;
    }
  }

  /// 在 Web 平台发起同源弹窗 SSO 登录，完成后返回 OIDC 会话。
  Future<OidcSession> signInWithPopup() {
    _start();
    final generation = _generation;
    // 必须在任何 await 前调用，以保留浏览器用户手势激活上下文。
    return _oidc
        .signInWithPopup()
        .then((session) {
          _check(generation);
          return session;
        })
        .onError<OidcFailure>((error, stack) {
          throw AuthFailure(error.code, error.message);
        })
        .whenComplete(() => _busy = false);
  }

  void _check(int generation) {
    if (_disposed || generation != _generation) {
      throw const AuthFailure('cancelled', '登录已取消。');
    }
  }

  /// 取消当前进行中的登录事务与流程请求。
  void cancel() {
    _generation++;
    _flow?.cancel();
    _oidc.cancelPending();
    final transaction = _transaction;
    if (transaction != null) _oidc.cancel(transaction);
  }

  /// 释放认证客户端及底层资源；调用后不可再发起登录。
  void dispose() {
    if (_disposed) return;
    cancel();
    _disposed = true;
    _oidc.dispose();
  }
}
