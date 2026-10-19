import 'package:diet_oidc/diet_oidc.dart';

import 'flow_stub.dart' if (dart.library.io) 'flow_native.dart';
import 'types.dart';

const _isWeb = bool.fromEnvironment('dart.library.js_interop');

class AuthentikAuthClient {
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

  Future<OidcSession> signInWithPopup() {
    _start();
    final generation = _generation;
    // Invoke before any await so the browser still has the user activation.
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

  void cancel() {
    _generation++;
    _flow?.cancel();
    _oidc.cancelPending();
    final transaction = _transaction;
    if (transaction != null) _oidc.cancel(transaction);
  }

  void dispose() {
    if (_disposed) return;
    cancel();
    _disposed = true;
    _oidc.dispose();
  }
}
