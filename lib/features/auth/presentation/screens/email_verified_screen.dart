import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/app_routes.dart';
import '../widgets/auth_preview_panel.dart';

class EmailVerifiedScreen extends StatelessWidget {
  const EmailVerifiedScreen({super.key});

  @override
  Widget build(BuildContext context) => AppPage(
    title: '邮箱验证结果',
    subtitle: '辅助流程预览结束',
    showBack: true,
    children: [
      AuthPreviewPanel(
        title: '验证完成预览',
        description: '你已浏览邮箱验证流程。\n没有验证真实邮箱，也没有激活账号。真实登录仍需通过身份服务校验。',
        icon: AppIcons.checkCircle,
        actions: [
          AppButton(
            label: '返回登录',
            onPressed: () => context.go(AppRoutes.login),
          ),
        ],
      ),
    ],
  );
}
