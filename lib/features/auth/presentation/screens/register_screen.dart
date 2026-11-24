import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/ui_preview_config.dart';
import '../../../../core/presentation/navigation_manager.dart';
import '../../application/auxiliary_controller.dart';
import '../widgets/auth_field.dart';
import '../widgets/auth_form_guard.dart';

/// 用户注册表单页面，支持真实注册提交与本地填写预览。
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nickname = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _dirty = false;
  int _submission = 0;
  late final AuxiliaryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(auxiliaryControllerProvider.notifier);
  }

  @override
  void dispose() {
    _submission++;
    _controller.cancelIfBusy();
    for (final controller in [_name, _nickname, _email, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final native = ref.read(nativeNutritionEnabledProvider);
    final navigation = ref.read(navigationManagerProvider);
    if (!native) {
      navigation.openVerifyEmail(context);
      return;
    }
    // 使用页面内提交序号隔离取消或销毁后才返回的老响应。
    final submission = ++_submission;
    final accepted = await _controller.register(
      username: _name.text,
      email: _email.text,
      password: _password.text,
      confirmPassword: _confirm.text,
      displayName: _nickname.text,
    );
    if (!mounted || submission != _submission) return;
    _password.clear();
    _confirm.clear();
    if (accepted) {
      setState(() => _dirty = false);
      navigation.openVerifyEmail(context);
    }
  }

  void _handleCancel() {
    _submission++;
    _controller.cancel();
    _password.clear();
    _confirm.clear();
  }

  void _handleBackToLogin() {
    final navigation = ref.read(navigationManagerProvider);
    if (_dirty) {
      navigation.maybePop(context);
    } else {
      navigation.goLogin(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final native = ref.watch(nativeNutritionEnabledProvider);
    final state = ref.watch(auxiliaryControllerProvider);
    return AuthFormGuard(
      dirty: _dirty,
      child: AppPage(
        title: '创建账号',
        subtitle: native ? '注册后请通过邮件验证，再返回登录' : '只预览填写与校验，不创建真实账号',
        showBack: true,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 490),
              child: _RegisterFormCard(
                formKey: _form,
                native: native,
                state: state,
                nameController: _name,
                nicknameController: _nickname,
                emailController: _email,
                passwordController: _password,
                confirmController: _confirm,
                onFormChanged: () => setState(() => _dirty = true),
                onSubmit: _handleSubmit,
                onCancel: _handleCancel,
              ),
            ),
          ),
          TextButton(
            onPressed: _handleBackToLogin,
            child: const Text('已有账号？返回登录'),
          ),
        ],
      ),
    );
  }
}

class _RegisterFormCard extends StatelessWidget {
  const _RegisterFormCard({
    required this.formKey,
    required this.native,
    required this.state,
    required this.nameController,
    required this.nicknameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmController,
    required this.onFormChanged,
    required this.onSubmit,
    required this.onCancel,
  });

  final GlobalKey<FormState> formKey;
  final bool native;
  final AuxiliaryState state;
  final TextEditingController nameController;
  final TextEditingController nicknameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final VoidCallback onFormChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Form(
      key: formKey,
      onChanged: onFormChanged,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            native ? '创建账号' : '注册流程演示',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            native
                ? '填写账号与邮箱。请求受理后请检查邮箱并在网页验证，客户端不会自动登录。'
                : '请使用虚构信息。这里只检查格式，不会发送邮件。',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 24),
          // 兼容 Authentik 不同表单流程返回的昵称及确认密码字段键名。
          AuthField(
            label: '用户名',
            controller: nameController,
            serverError: state.fields['username'],
          ),
          AuthField(
            label: '昵称（可选）',
            controller: nicknameController,
            serverError:
                state.fields['nickname'] ??
                state.fields['name'] ??
                state.fields['display_name'],
            validator: (_) => null,
          ),
          AuthField(
            label: '邮箱',
            controller: emailController,
            serverError: state.fields['email'],
            email: true,
            validator: validateEmail,
          ),
          AuthField(
            label: '密码',
            controller: passwordController,
            serverError: state.fields['password'],
            password: true,
            validator: (v) => (v?.length ?? 0) < 8 ? '密码至少填写 8 位' : null,
          ),
          AuthField(
            label: '确认密码',
            controller: confirmController,
            serverError:
                state.fields['password-repeat'] ??
                state.fields['password_repeat'],
            password: true,
            validator: (v) =>
                v != passwordController.text ? '两次输入的密码不一致' : null,
          ),
          if (native && state.error != null) ...[
            InfoBanner(text: state.error!, color: AppColors.red),
            const SizedBox(height: 12),
          ],
          if (native && state.notice != null) Text(state.notice!),
          AppButton(
            label: state.busy && native
                ? '正在提交…'
                : native
                ? '注册并发送验证邮件'
                : '继续验证演示',
            onPressed: native && state.busy ? null : onSubmit,
          ),
          if (native && state.busy)
            TextButton(onPressed: onCancel, child: const Text('取消提交')),
        ],
      ),
    ),
  );
}
