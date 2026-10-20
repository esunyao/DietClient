import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/app_routes.dart';
import '../widgets/auth_preview_panel.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) => AppPage(
    title: '验证邮箱',
    subtitle: '注册辅助流程预览',
    showBack: true,
    children: [
      AuthPreviewPanel(
        title: '查看邮箱验证步骤',
        description: '真实流程会通过邮件确认邮箱归属。\n本演示没有发送邮件，也不会修改真实账号状态。',
        icon: AppIcons.envelope,
        actions: [
          AppButton(
            label: '模拟邮箱验证完成',
            onPressed: () => context.push(AppRoutes.emailVerified),
          ),
          AppButton(
            label: '重新发送（演示）',
            secondary: true,
            onPressed: () => showDemoMessage(context, '仅演示重新发送反馈，没有发送邮件。'),
          ),
        ],
      ),
    ],
  );
}
