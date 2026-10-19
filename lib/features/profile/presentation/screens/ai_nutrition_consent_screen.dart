import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/demo/demo_store.dart';

class AiNutritionConsentScreen extends ConsumerWidget {
  const AiNutritionConsentScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(demoProvider.select((s) => s.aiConsent));
    return AppPage(
      title: 'AI 数据与隐私',
      subtitle: '用途说明与开关预览',
      showBack: true,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: AppColors.primary,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text('AI 营养分析', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              AppBadge(label: enabled ? '演示开关已开启' : '演示开关已关闭'),
              const SizedBox(height: 12),
              const Text('本页仅改变共享的内存预览状态，不授予真实数据访问权限，也不会发起 AI 请求。'),
            ],
          ),
        ),
        const SectionHeading(title: '分析用途预览'),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('基础资料与最近测量'),
              SizedBox(height: 8),
              Text('有效健康目标、过敏、疾病与饮食限制'),
              SizedBox(height: 8),
              Text('本次确认的餐食及份量'),
            ],
          ),
        ),
        const InfoBanner(text: '填写健康档案不等于同意 AI 使用。真实接入前需单独确认用途、资料范围和授权状态。'),
        AppButton(
          label: enabled ? '关闭本次演示开关' : '开启本次演示开关',
          secondary: enabled,
          onPressed: () async {
            if (enabled) {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('关闭演示开关？'),
                  content: const Text('只改变本次预览，不涉及真实授权的撤回。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('保持开启'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('关闭演示开关'),
                    ),
                  ],
                ),
              );
              if (confirm != true || !context.mounted) return;
            }
            ref.read(demoProvider.notifier).setAiConsent(!enabled);
            if (context.mounted)
              showDemoMessage(
                context,
                enabled ? '演示开关已关闭，没有修改真实授权。' : '演示开关已开启，没有授予真实权限。',
              );
          },
        ),
      ],
    );
  }
}
