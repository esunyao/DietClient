import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/ui_preview_config.dart';
import '../../../../core/presentation/app_routes.dart';
import '../../application/auxiliary_controller.dart';
import '../widgets/auth_field.dart';
import '../widgets/auth_preview_panel.dart';

/// @brief 邮箱验证等待与重发页面。
/// @details 原生分支提供重发验证邮件与返回登录入口；演示分支不发送邮件，也不确认真实验证结果。
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _email = TextEditingController();
  final _form = GlobalKey<FormState>();
  late final AuxiliaryController _controller;

  /// @brief 初始化状态并从辅助流程状态预填邮箱地址。
  /// @note 页面销毁时自动取消仍在进行中的辅助操作。
  @override
  void initState() {
    super.initState();
    _controller = ref.read(auxiliaryControllerProvider.notifier);
    _email.text = ref.read(auxiliaryControllerProvider).email;
  }

  @override
  void dispose() {
    _controller.cancelIfBusy();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final native = ref.watch(nativeNutritionEnabledProvider);
    final state = ref.watch(auxiliaryControllerProvider);
    return AppPage(
      title: '验证邮箱',
      subtitle: native ? '请在邮件网页完成验证，再手动返回登录' : '注册辅助流程预览',
      showBack: true,
      children: [
        AuthPreviewPanel(
          title: native
              ? state.verificationRequired
                    ? '需要验证邮箱'
                    : '重发验证邮件'
              : '查看邮箱验证步骤',
          description: native
              ? '若该邮箱需要验证，请检查收件箱及垃圾邮件文件夹。\n客户端无法确认网页验证结果；完成后请返回登录。'
              : '真实流程会通过邮件确认邮箱归属。\n本演示没有发送邮件，也不会修改真实账号状态。',
          icon: AppIcons.envelope,
          actions: native
              ? [
                  Form(
                    key: _form,
                    child: AuthField(
                      label: '邮箱',
                      controller: _email,
                      email: true,
                      validator: validateEmail,
                      serverError: state.fields['email'],
                    ),
                  ),
                  if (state.error != null)
                    InfoBanner(text: state.error!, color: AppColors.red),
                  if (state.notice != null) Text(state.notice!),
                  // 按控制器的忙碌和受理后冷却状态限制重发。
                  AppButton(
                    label: state.busy
                        ? '正在受理…'
                        : state.cooldown > 0
                        ? '${state.cooldown} 秒后可重发'
                        : '重新发送验证邮件',
                    secondary: true,
                    onPressed: state.busy || state.cooldown > 0
                        ? null
                        : () {
                            if (_form.currentState!.validate()) {
                              ref
                                  .read(auxiliaryControllerProvider.notifier)
                                  .resend(_email.text);
                            }
                          },
                  ),
                  if (state.busy)
                    TextButton(
                      onPressed: () => ref
                          .read(auxiliaryControllerProvider.notifier)
                          .cancel(),
                      child: const Text('取消'),
                    ),
                  AppButton(
                    label: '返回登录',
                    onPressed: state.busy
                        ? null
                        : () => context.go(AppRoutes.login),
                  ),
                ]
              : [
                  AppButton(
                    label: '模拟邮箱验证完成',
                    onPressed: () => context.push(AppRoutes.emailVerified),
                  ),
                  AppButton(
                    label: '重新发送（演示）',
                    secondary: true,
                    onPressed: () =>
                        showDemoMessage(context, '仅演示重新发送反馈，没有发送邮件。'),
                  ),
                ],
        ),
      ],
    );
  }
}
