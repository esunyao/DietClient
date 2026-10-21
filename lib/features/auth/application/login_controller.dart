import 'dart:async';

import 'package:diet_auth/diet_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/auth_config.dart';
import '../../../core/session/session_controller.dart';

/// 薄可替换边界供无网络门禁/取消测试使用。
abstract interface class AuthGateway {
  Future<OidcSession> password({
    required String username,
    required String password,
    Future<bool> Function(AuthentikConsent)? onConsent,
  });
  Future<OidcSession> popup();
  void cancel();
  void dispose();
}

class _AuthentikGateway implements AuthGateway {
  _AuthentikGateway(AuthentikConfig config)
    : client = AuthentikAuthClient(config);
  final AuthentikAuthClient client;
  @override
  Future<OidcSession> password({
    required String username,
    required String password,
    Future<bool> Function(AuthentikConsent)? onConsent,
  }) => client.signInWithPassword(
    username: username,
    password: password,
    onConsent: onConsent,
  );
  @override
  Future<OidcSession> popup() => client.signInWithPopup();
  @override
  void cancel() => client.cancel();
  @override
  void dispose() => client.dispose();
}

final authGatewayProvider = Provider<AuthGateway?>((ref) {
  final config = ref.watch(authConfigProvider).authentik;
  if (config == null) return null;
  final gateway = _AuthentikGateway(config);
  ref.onDispose(gateway.dispose);
  return gateway;
});

class LoginState {
  const LoginState({this.busy = false, this.error, this.cancelled = false});
  final bool busy;
  final String? error;
  final bool cancelled;
}

final loginControllerProvider = NotifierProvider<LoginController, LoginState>(
  LoginController.new,
);

class LoginController extends Notifier<LoginState> {
  int _attempt = 0;
  Completer<bool>? _consent;
  @override
  LoginState build() {
    ref.onDispose(() {
      _attempt++;
      if (_consent?.isCompleted == false) _consent!.complete(false);
    });
    return const LoginState();
  }

  Future<void> signIn({
    String? username,
    String? password,
    required bool popup,
    bool rememberMe = false,
    Future<bool> Function(AuthentikConsent)? onConsent,
  }) async {
    if (state.busy) return;
    final gateway = ref.read(authGatewayProvider);
    if (gateway == null) {
      state = const LoginState(error: '登录配置不完整，当前无法连接。');
      return;
    }
    if (!popup &&
        ((username?.trim().isEmpty ?? true) || (password?.isEmpty ?? true))) {
      state = const LoginState(error: '请填写用户名和密码。');
      return;
    }
    final attempt = ++_attempt;
    state = const LoginState(busy: true);
    try {
      final session = popup
          ? await gateway.popup()
          : await gateway.password(
              username: username!.trim(),
              password: password!,
              onConsent: (consent) async {
                if (attempt != _attempt || onConsent == null) return false;
                final pending = Completer<bool>();
                _consent = pending;
                try {
                  return await Future.any([
                        onConsent(consent),
                        pending.future,
                      ]) &&
                      attempt == _attempt;
                } finally {
                  if (identical(_consent, pending)) _consent = null;
                }
              },
            );
      if (attempt != _attempt) return;
      if (!hasActiveSession(session)) {
        state = const LoginState(error: '服务器返回的会话已过期，请重新登录。');
        return;
      }
      await ref
          .read(sessionProvider.notifier)
          .establish(session, rememberMe: !popup && rememberMe);
      if (!ref.mounted || attempt != _attempt) return;
      state = const LoginState();
    } on AuthFailure catch (failure) {
      if (attempt != _attempt) return;
      state = failure.code == 'cancelled'
          ? const LoginState(cancelled: true)
          : LoginState(error: failure.message);
    } catch (_) {
      if (attempt == _attempt) state = const LoginState(error: '暂时无法完成登录，请重试。');
    }
  }

  void cancel() {
    _attempt++;
    if (_consent?.isCompleted == false) _consent!.complete(false);
    _consent = null;
    ref.read(authGatewayProvider)?.cancel();
    state = const LoginState(cancelled: true);
  }
}
