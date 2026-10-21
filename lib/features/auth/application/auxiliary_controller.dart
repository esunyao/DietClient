import 'dart:async';

import 'package:diet_auth/diet_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/auth_config.dart';
import '../../../core/config/ui_preview_config.dart';

abstract interface class AuxiliaryGateway {
  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
    String displayName,
  });
  Future<void> resend(String email);
  void cancel();
  Future<void> dispose();
}

class _Gateway implements AuxiliaryGateway {
  _Gateway(AuthentikConfig config) : executor = AuxiliaryFlowExecutor(config);
  final AuxiliaryFlowExecutor executor;
  @override
  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
    String displayName = '',
  }) => executor.register(
    username: username,
    email: email,
    password: password,
    confirmPassword: confirmPassword,
    displayName: displayName,
  );
  @override
  Future<void> resend(String email) => executor.resend(email);
  @override
  void cancel() => executor.cancel();
  @override
  Future<void> dispose() => executor.dispose();
}

final auxiliaryGatewayFactoryProvider = Provider<AuxiliaryGateway Function()?>((
  ref,
) {
  if (!ref.watch(nativeNutritionEnabledProvider)) return null;
  final config = ref.watch(authConfigProvider).authentik;
  return config == null ? null : () => _Gateway(config);
});

class AuxiliaryState {
  const AuxiliaryState({
    this.busy = false,
    this.error,
    this.fields = const {},
    this.email = '',
    this.verificationRequired = false,
    this.cooldown = 0,
    this.notice,
  });
  final bool busy;
  final String? error;
  final Map<String, String> fields;
  final String email;
  final bool verificationRequired;
  final int cooldown;
  final String? notice;
  AuxiliaryState withCooldown(int value) => AuxiliaryState(
    busy: busy,
    error: error,
    fields: fields,
    email: email,
    verificationRequired: verificationRequired,
    cooldown: value,
    notice: notice,
  );
}

final auxiliaryControllerProvider =
    NotifierProvider<AuxiliaryController, AuxiliaryState>(
      AuxiliaryController.new,
    );

final auxiliaryNowProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

class AuxiliaryController extends Notifier<AuxiliaryState> {
  int _attempt = 0;
  AuxiliaryGateway? _gateway;
  Timer? _timer;
  DateTime? _cooldownUntil;
  int get _remaining => _cooldownUntil == null
      ? 0
      : ((_cooldownUntil!
                        .difference(ref.read(auxiliaryNowProvider)())
                        .inMilliseconds +
                    999) ~/
                1000)
            .clamp(0, 60);
  @override
  AuxiliaryState build() {
    ref.onDispose(() {
      _attempt++;
      _timer?.cancel();
      _gateway?.cancel();
    });
    return const AuxiliaryState();
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
    String displayName = '',
  }) => _execute(
    email,
    false,
    (gateway) => gateway.register(
      username: username,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      displayName: displayName,
    ),
  );
  Future<bool> resend(String email) =>
      _execute(email, true, (gateway) => gateway.resend(email));
  Future<bool> _execute(
    String email,
    bool resend,
    Future<void> Function(AuxiliaryGateway) action,
  ) async {
    if (state.busy || (resend && _remaining > 0)) return false;
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email.trim())) {
      state = AuxiliaryState(
        email: email,
        error: '请输入有效的邮箱地址',
        fields: const {'email': '请输入有效的邮箱地址'},
      );
      return false;
    }
    final factory = ref.read(auxiliaryGatewayFactoryProvider);
    if (factory == null) {
      state = AuxiliaryState(email: email, error: '注册或邮件服务配置不可用。');
      return false;
    }
    final attempt = ++_attempt;
    AuxiliaryGateway? gateway;
    state = AuxiliaryState(
      busy: true,
      email: email.trim(),
      cooldown: _remaining,
    );
    try {
      gateway = factory();
      _gateway = gateway;
      await action(gateway);
      if (!ref.mounted || attempt != _attempt) return false;
      if (resend) {
        _cooldownUntil = ref
            .read(auxiliaryNowProvider)()
            .add(const Duration(seconds: 60));
      }
      state = AuxiliaryState(
        email: email.trim(),
        verificationRequired: true,
        cooldown: _remaining,
        notice: resend ? '请求已受理；若该邮箱需要验证，请检查收件箱及垃圾邮件。' : null,
      );
      if (resend) {
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!ref.mounted) {
            timer.cancel();
            return;
          }
          state = state.withCooldown(_remaining);
          if (_remaining == 0) timer.cancel();
        });
      }
      return true;
    } on AuthFailure catch (e) {
      if (ref.mounted && attempt == _attempt) {
        state = AuxiliaryState(
          email: email,
          cooldown: _remaining,
          error: e.message,
          fields: e is AuthFieldFailure ? e.fields : const {},
        );
      }
    } catch (_) {
      if (ref.mounted && attempt == _attempt) {
        state = AuxiliaryState(
          email: email,
          cooldown: _remaining,
          error: '未能确认结果，请先检查验证邮件，避免重复提交。',
        );
      }
    } finally {
      if (identical(_gateway, gateway)) _gateway = null;
      try {
        await gateway?.dispose();
      } catch (_) {
        // Cleanup cannot change an already confirmed or cancelled result.
      }
    }
    return false;
  }

  void cancelIfBusy() {
    if (ref.mounted && state.busy) cancel();
  }

  void cancel() {
    _attempt++;
    _gateway?.cancel();
    state = AuxiliaryState(
      email: state.email,
      cooldown: _remaining,
      notice: '操作已取消；如已提交，请先检查邮箱再重试。',
    );
  }
}
