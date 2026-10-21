import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/ui_preview_config.dart';
import '../../application/auxiliary_controller.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/core/presentation/app_routes.dart';

import '../widgets/auth_field.dart';
import '../widgets/auth_form_guard.dart';

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
    for (final c in [_name, _nickname, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
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
              child: AppCard(
                child: Form(
                  key: _form,
                  onChanged: () => setState(() => _dirty = true),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        native ? '创建账号' : '注册流程演示',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        native
                            ? '填写账号与邮箱。请求受理后请检查邮箱并在网页验证，客户端不会自动登录。'
                            : '请使用虚构信息。这里只检查格式，不会发送邮件。',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AuthField(
                        label: '用户名',
                        controller: _name,
                        serverError: state.fields['username'],
                      ),
                      AuthField(
                        label: '昵称（可选）',
                        controller: _nickname,
                        serverError:
                            state.fields['nickname'] ??
                            state.fields['name'] ??
                            state.fields['display_name'],
                        validator: (_) => null,
                      ),
                      AuthField(
                        label: '邮箱',
                        controller: _email,
                        serverError: state.fields['email'],
                        email: true,
                        validator: validateEmail,
                      ),
                      AuthField(
                        label: '密码',
                        controller: _password,
                        serverError: state.fields['password'],
                        password: true,
                        validator: (v) =>
                            (v?.length ?? 0) < 8 ? '密码至少填写 8 位' : null,
                      ),
                      AuthField(
                        label: '确认密码',
                        controller: _confirm,
                        serverError:
                            state.fields['password-repeat'] ??
                            state.fields['password_repeat'],
                        password: true,
                        validator: (v) =>
                            v != _password.text ? '两次输入的密码不一致' : null,
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
                        onPressed: native && state.busy
                            ? null
                            : () async {
                                if (!_form.currentState!.validate()) return;
                                FocusScope.of(context).unfocus();
                                if (!native) {
                                  context.push(AppRoutes.verifyEmail);
                                  return;
                                }
                                final submission = ++_submission;
                                final accepted = await _controller.register(
                                  username: _name.text,
                                  email: _email.text,
                                  password: _password.text,
                                  confirmPassword: _confirm.text,
                                  displayName: _nickname.text,
                                );
                                if (!mounted || submission != _submission) {
                                  return;
                                }
                                _password.clear();
                                _confirm.clear();
                                if (accepted) {
                                  setState(() => _dirty = false);
                                  if (context.mounted) {
                                    context.push(AppRoutes.verifyEmail);
                                  }
                                }
                              },
                      ),
                      if (native && state.busy)
                        TextButton(
                          onPressed: () {
                            _submission++;
                            _controller.cancel();
                            _password.clear();
                            _confirm.clear();
                          },
                          child: const Text('取消提交'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              if (_dirty) {
                Navigator.of(context).maybePop();
              } else {
                context.go(AppRoutes.login);
              }
            },
            child: const Text('已有账号？返回登录'),
          ),
        ],
      ),
    );
  }
}
