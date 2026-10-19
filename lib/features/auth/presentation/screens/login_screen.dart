import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/core/presentation/app_routes.dart';

import '../widgets/auth_field.dart';
import '../widgets/auth_form_guard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _validated = false;
  bool _dirty = false;
  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthFormGuard(
    dirty: _dirty,
    child: AppPage(
      title: '欢迎回来',
      subtitle: 'Diet · 让每一餐更了解你',
      children: [
        const Center(child: PlateIllustration(size: 104)),
        AppCard(
          child: Form(
            key: _form,
            onChanged: () => setState(() {
              _dirty = true;
              _validated = false;
            }),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('登录', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('体验你的饮食与健康空间'),
                const SizedBox(height: 24),
                AuthField(label: '用户名或邮箱', controller: _username),
                AuthField(label: '密码', controller: _password, password: true),
                AppButton(
                  label: '检查演示表单',
                  onPressed: () {
                    if (_form.currentState!.validate()) {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _validated = true;
                        _dirty = false;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        if (_validated) ...[
          const InfoBanner(text: '格式检查通过。这是本地界面演示，未验证账号或登录。'),
          AppButton(
            label: '进入演示首页',
            onPressed: () => context.go(AppRoutes.home),
          ),
        ],
        AppButton(
          label: '创建账号',
          secondary: true,
          onPressed: () => context.push(AppRoutes.register),
        ),
        TextButton(
          onPressed: () => context.push(AppRoutes.verifyEmail),
          child: const Text('查看邮箱验证演示'),
        ),
        const Text(
          '请使用虚构信息体验。输入内容不会发送至服务器。',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
      ],
    ),
  );
}
