import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../demo/demo_store.dart';
import '../../../../core/config/ui_preview_config.dart';
import 'real_consent_screen.dart';

class AiNutritionConsentScreen extends ConsumerWidget {
  const AiNutritionConsentScreen({super.key});

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (enabled) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('关闭演示开关？'),
          content: const Text('只改变本次预览，不涉及真实授权的撤回。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('保持开启'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('关闭演示开关'),
            ),
          ],
        ),
      );
      if (confirm != true || !context.mounted) return;
    }
    ref.read(demoProvider.notifier).setAiConsent(!enabled);
    if (context.mounted) {
      showDemoMessage(
        context,
        enabled ? '演示开关已关闭，没有修改真实授权。' : '演示开关已开启，没有授予真实权限。',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(uiPreviewProvider)) return const RealConsentScreen();
    final enabled = ref.watch(demoProvider.select((s) => s.aiConsent));
    return AppPage(
      title: 'AI 数据与隐私',
      subtitle: '用途说明与开关预览',
      showBack: true,
      footer: AppButton(
        label: enabled ? '关闭本次演示开关' : '开启本次演示开关',
        secondary: enabled,
        onPressed: () => _toggle(context, ref, enabled),
      ),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    AppIcons.shield,
                    size: 30,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI 营养分析',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppBadge(label: enabled ? '演示开关已开启' : '演示开关已关闭'),
              const SizedBox(height: 12),
              const Text(
                '仅改变共享的内存预览状态，不授予真实数据访问权限，也不会发起 AI 请求。',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        const SectionHeading(title: '分析用途预览'),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ConsentScope(title: '基础资料与最近测量', description: '查看记录背景，不覆盖历史测量'),
              Divider(height: 24),
              _ConsentScope(
                title: '目标、过敏、疾病与饮食限制',
                description: '未填写的信息保持未知，冲突需进一步核实',
              ),
              Divider(height: 24),
              _ConsentScope(title: '本次确认的餐食及份量', description: '仅用于相应用途的营养分析预览'),
            ],
          ),
        ),
        const AppCard(
          color: AppColors.greenSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '资料录入不等于授权',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 12),
              Text(
                '填写健康档案、加入机构和 AI 使用授权分别判断。真实接入前需单独确认用途、资料范围和授权状态。',
                style: TextStyle(fontSize: 14, height: 1.8),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConsentScope extends StatelessWidget {
  const _ConsentScope({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 6),
      Text(
        description,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.muted,
          height: 1.6,
        ),
      ),
    ],
  );
}
