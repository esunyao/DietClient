import 'package:diet_auth/diet_auth.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/auth_config.dart';
import '../../../../core/presentation/app_routes.dart';
import '../../application/login_controller.dart';
import '../widgets/auth_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  BuildContext? _consentContext;
  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<bool> _confirmConsent(AuthentikConsent consent) async {
    if (!mounted) return false;
    try {
      return await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              _consentContext = dialogContext;
              return AlertDialog(
                title: Text(consent.title),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('请确认本次登录请求的权限：'),
                      const SizedBox(height: 12),
                      for (final permission in consent.permissions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('• $permission'),
                        ),
                      if (consent.permissions.isEmpty)
                        const Text('服务端未提供权限说明，请仅在确认用途后继续。'),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('取消登录'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('同意并继续'),
                  ),
                ],
              );
            },
          ) ??
          false;
    } finally {
      _consentContext = null;
    }
  }

  void _dismissConsent() {
    final dialog = _consentContext;
    if (dialog == null || !dialog.mounted) return;
    final route = ModalRoute.of(dialog);
    if (route != null && route.isActive) {
      Navigator.of(dialog).removeRoute(route, false);
    }
    _consentContext = null;
  }

  Future<void> _signIn() async {
    if (!kIsWeb && !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(loginControllerProvider.notifier)
        .signIn(
          username: _username.text,
          password: _password.text,
          popup: kIsWeb,
          onConsent: _confirmConsent,
        );
    if (mounted) _password.clear();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(authConfigProvider);
    final login = ref.watch(loginControllerProvider);
    ref.listen(loginControllerProvider, (previous, next) {
      if (!next.busy) _dismissConsent();
    });
    return PopScope(
      canPop: !login.busy,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 490),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(AppIcons.plan, size: 25, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text(
                          '膳食健康',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: PlateIllustration(size: 72),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '欢迎回来',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '登录膳食健康，连接你的身份服务',
                      style: TextStyle(color: AppColors.muted, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    AppCard(
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              '账号登录',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (kIsWeb)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 20),
                                child: Text('通过 Authentik 单点登录。此页面不会收集你的密码。'),
                              ),
                            if (!kIsWeb)
                              AutofillGroup(
                                child: AbsorbPointer(
                                  absorbing: login.busy,
                                  child: Column(
                                    children: [
                                      AuthField(
                                        label: '用户名或邮箱',
                                        controller: _username,
                                        validator: (value) =>
                                            value == null ||
                                                value.trim().isEmpty
                                            ? '请填写用户名或邮箱'
                                            : null,
                                      ),
                                      AuthField(
                                        label: '密码',
                                        controller: _password,
                                        password: true,
                                        validator: (value) =>
                                            value == null || value.isEmpty
                                            ? '请填写密码'
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            AppButton(
                              label: login.busy
                                  ? '正在登录…'
                                  : kIsWeb
                                  ? '通过 SSO 弹窗登录'
                                  : '登录',
                              icon: AppIcons.signIn,
                              onPressed: login.busy || !config.isReady
                                  ? null
                                  : _signIn,
                            ),
                            if (login.busy) ...[
                              const SizedBox(height: 16),
                              const LinearProgressIndicator(),
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(loginControllerProvider.notifier)
                                      .cancel();
                                  _password.clear();
                                },
                                child: const Text('取消登录'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (!config.isReady)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: InfoBanner(
                          text: '登录暂不可用：\n${config.issues.join('\n')}',
                          color: AppColors.amberInk,
                        ),
                      ),
                    if (login.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: InfoBanner(
                          text: '${login.error}\n可检查后重新尝试。',
                          color: AppColors.red,
                        ),
                      ),
                    if (login.cancelled)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text(
                          '本次登录已取消，可重新开始。',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    const SizedBox(height: 20),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          AppIcons.shield,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '登录连接真实身份服务。膳食业务仍使用演示数据；登录会话只保留在内存，关闭或过期后需重新登录。',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                              height: 1.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: login.busy
                          ? null
                          : () => context.push(AppRoutes.register),
                      child: const Text('查看注册界面演示'),
                    ),
                    TextButton(
                      onPressed: login.busy
                          ? null
                          : () => context.push(AppRoutes.verifyEmail),
                      child: const Text('查看邮箱验证演示'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
