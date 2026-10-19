import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/core/presentation/app_routes.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    title: '验证邮箱',
    subtitle: '注册流程预览',
    showBack: true,
    children: [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.mark_email_unread_outlined,
              size: 54,
              color: AppColors.blue,
            ),
            const SizedBox(height: 20),
            Text(
              '请检查你的邮箱',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              '真实流程会通过验证邮件确认邮箱归属。本演示没有发送邮件，点击下方按钮预览下一步。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: '模拟邮箱验证完成',
              onPressed: () => context.push(AppRoutes.emailVerified),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: '重新发送（演示）',
              secondary: true,
              onPressed: () => showDemoMessage(context, '仅演示重新发送反馈，没有发送邮件。'),
            ),
          ],
        ),
      ),
    ],
  );
}
