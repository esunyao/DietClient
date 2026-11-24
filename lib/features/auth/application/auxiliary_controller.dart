import 'dart:async';

import 'package:diet_auth/diet_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/auth_config.dart';
import '../../../core/config/ui_preview_config.dart';

/// 注册与验证邮件重发网关抽象接口，便于测试替换。
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

/// 认证辅助网关工厂 Provider，每次操作创建独立网关实例。
final auxiliaryGatewayFactoryProvider = Provider<AuxiliaryGateway Function()?>((
  ref,
) {
  if (!ref.watch(nativeNutritionEnabledProvider)) return null;
  final config = ref.watch(authConfigProvider).authentik;
  return config == null ? null : () => _Gateway(config);
});

/// 注册与重发邮件流程状态模型。
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

  /// 复制并更新重发冷却秒数。
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

/// 认证辅助控制器 Provider。
final auxiliaryControllerProvider =
    NotifierProvider<AuxiliaryController, AuxiliaryState>(
      AuxiliaryController.new,
    );

/// 辅助流程时钟 Provider，用于计算重发冷却与单元测试注入。
final auxiliaryNowProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// 注册与重发验证邮件状态控制器，按尝试编号隔离过期响应。
class AuxiliaryController extends Notifier<AuxiliaryState> {
  int _attempt = 0;
  AuxiliaryGateway? _gateway;
  Timer? _timer;
  DateTime? _cooldownUntil;

  // 按冷却截止时间计算向上取整的剩余秒数，定时器仅触发界面刷新。
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

  /// 提交注册表单，返回服务端是否受理本次请求。
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

  /// 重发验证邮件，受理后开启 60 秒冷却。
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
      if (resend) _startCooldown();
      state = AuxiliaryState(
        email: email.trim(),
        verificationRequired: true,
        cooldown: _remaining,
        notice: resend ? '请求已受理；若该邮箱需要验证，请检查收件箱及垃圾邮件。' : null,
      );
      return true;
    } on AuthFailure catch (failure) {
      if (ref.mounted && attempt == _attempt) {
        state = AuxiliaryState(
          email: email,
          cooldown: _remaining,
          error: failure.message,
          fields: failure is AuthFieldFailure ? failure.fields : const {},
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
        // 清理失败不覆盖已确认或已取消的结果。
      }
    }
    return false;
  }

  void _startCooldown() {
    _cooldownUntil = ref
        .read(auxiliaryNowProvider)()
        .add(const Duration(seconds: 60));
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

  /// 离开页面前若存在进行中操作则安全取消。
  void cancelIfBusy() {
    if (ref.mounted && state.busy) cancel();
  }

  /// 取消当前注册或重发请求并使旧回调失效。
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
