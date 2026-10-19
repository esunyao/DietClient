import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/core/presentation/app_routes.dart';

class EmailVerifiedScreen extends StatelessWidget {
  const EmailVerifiedScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    title: '邮箱验证结果',
    subtitle: '流程演示完成',
    showBack: true,
    children: [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.green,
              size: 60,
            ),
            const SizedBox(height: 20),
            Text(
              '验证完成预览',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              '你已浏览邮箱验证流程。没有验证真实邮箱，也没有激活账号。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: '返回登录',
              onPressed: () => context.go(AppRoutes.login),
            ),
          ],
        ),
      ),
    ],
  );
}
