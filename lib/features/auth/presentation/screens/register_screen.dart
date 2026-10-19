import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/core/presentation/app_routes.dart';

import '../widgets/auth_field.dart';
import '../widgets/auth_form_guard.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nickname = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _dirty = false;
  @override
  void dispose() {
    for (final c in [_name, _nickname, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthFormGuard(
    dirty: _dirty,
    child: AppPage(
      title: '创建账号',
      subtitle: '开启更有意识的饮食记录',
      showBack: true,
      children: [
        const InfoBanner(text: '注册流程演示：只检查格式，不会创建真实账号或发送邮件。'),
        AppCard(
          child: Form(
            key: _form,
            onChanged: () => setState(() => _dirty = true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthField(label: '用户名', controller: _name),
                AuthField(
                  label: '昵称（可选）',
                  controller: _nickname,
                  validator: (_) => null,
                ),
                AuthField(
                  label: '邮箱',
                  controller: _email,
                  email: true,
                  validator: validateEmail,
                ),
                AuthField(
                  label: '密码',
                  controller: _password,
                  password: true,
                  validator: (v) =>
                      (v?.length ?? 0) < 8 ? '演示密码至少填写 8 位' : null,
                ),
                AuthField(
                  label: '确认密码',
                  controller: _confirm,
                  password: true,
                  validator: (v) => v != _password.text ? '两次输入的密码不一致' : null,
                ),
                AppButton(
                  label: '继续验证演示',
                  onPressed: () {
                    if (_form.currentState!.validate()) {
                      FocusScope.of(context).unfocus();
                      context.push(AppRoutes.verifyEmail);
                    }
                  },
                ),
              ],
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
