import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/ui_preview_config.dart';
import '../../../../core/presentation/navigation_manager.dart';
import '../widgets/auth_preview_panel.dart';

/// 邮箱验证结果回执页，引导用户返回登录。
class EmailVerifiedScreen extends ConsumerWidget {
  const EmailVerifiedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final native = ref.watch(nativeNutritionEnabledProvider);
    return AppPage(
      title: '邮箱验证结果',
      subtitle: native ? '请返回登录验证账号状态' : '辅助流程预览结束',
      showBack: true,
      children: [
        AuthPreviewPanel(
          title: native ? '网页验证后返回登录' : '验证完成预览',
          description: native
              ? '客户端没有接收邮箱验证结果。请在邮件网页完成验证，然后重新登录。'
              : '你已浏览邮箱验证流程。\n没有验证真实邮箱，也没有激活账号。真实登录仍需通过身份服务校验。',
          icon: AppIcons.checkCircle,
          actions: [
            AppButton(
              label: '返回登录',
              onPressed: () =>
                  ref.read(navigationManagerProvider).goLogin(context),
            ),
          ],
        ),
      ],
    );
  }
}
