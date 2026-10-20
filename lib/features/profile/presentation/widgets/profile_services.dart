import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/app_routes.dart';
import '../../../../demo/demo_store.dart';
import 'health_kind.dart';

class ProfileInstitutionCard extends StatelessWidget {
  const ProfileInstitutionCard({super.key});

  @override
  Widget build(BuildContext context) => AppCard(
    radius: 16,
    color: AppColors.greenSoft,
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(title: '机构服务'),
        const SizedBox(height: 16),
        const Text(
          '医疗院',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          '一号食堂 · 个人成员（虚构机构）',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        const Text('仅用于菜单与餐食关联', style: TextStyle(color: AppColors.muted)),
        const Divider(height: 32),
        const Text(
          '机构成员身份不自动开放你的病史、过敏或个人报告。',
          style: TextStyle(color: AppColors.ink, fontSize: 14, height: 1.7),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.push(AppRoutes.institutionMenu),
          child: const Text('查看食堂菜单'),
        ),
      ],
    ),
  );
}

class ProfilePrivacyCard extends ConsumerWidget {
  const ProfilePrivacyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppCard(
    radius: 16,
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(AppIcons.shield, color: AppColors.primary, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '共享平板，保护隐私',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          '离开前隐藏个人信息或退出当前应用',
          style: TextStyle(color: AppColors.muted, fontSize: 14),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: '暂时隐藏个人信息',
          icon: AppIcons.shield,
          secondary: true,
          onPressed: () =>
              ref.read(demoProvider.notifier).setPrivacyHidden(true),
        ),
      ],
    ),
  );
}

class ProfileServiceEntries extends StatelessWidget {
  const ProfileServiceEntries({super.key, required this.institution});

  final bool institution;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: 16,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ProfileEntryRow(
                title: '我的报告',
                subtitle: '查看周期摘要与历史版本',
                icon: AppIcons.reports,
                onTap: () => context.push(AppRoutes.reports),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: ProfileEntryRow(
                title: '饮食历史',
                subtitle: '按日期查看个人餐食',
                icon: AppIcons.history,
                onTap: () => context.push(AppRoutes.mealHistory),
              ),
            ),
          ],
        ),
        const Divider(height: 1),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ProfileEntryRow(
                title: 'AI 数据与隐私',
                subtitle: '查看用途与演示开关',
                icon: AppIcons.shield,
                onTap: () => context.push(AppRoutes.aiConsent),
              ),
            ),
            if (institution) ...[
              const SizedBox(width: 24),
              Expanded(
                child: ProfileEntryRow(
                  title: '机构餐食同步',
                  subtitle: '核对待确认的机构餐食',
                  icon: AppIcons.sync,
                  onTap: () => context.push(AppRoutes.institutionSync),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

class ProfileAccountCard extends StatelessWidget {
  const ProfileAccountCard({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final logout = AppPageScope.of(context)?.onLogout;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出当前应用？'),
        content: const Text(
          '退出将清除当前应用的内存登录会话，返回真实登录入口。不会注销身份服务中的 SSO 会话，也不会向身份服务发起全局注销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('继续使用'),
          ),
          FilledButton(
            onPressed: logout == null
                ? null
                : () => Navigator.pop(dialogContext, true),
            child: const Text('退出当前应用'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) logout?.call();
  }

  @override
  Widget build(BuildContext context) => AppCard(
    radius: MediaQuery.sizeOf(context).width >= 1024 ? 16 : 20,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    child: Column(
      children: [
        ProfileEntryRow(
          title: '应用设置',
          subtitle: '显示、体验模式与帮助',
          icon: AppIcons.settings,
          onTap: () => context.push(AppRoutes.settings),
        ),
        if (!(AppPageScope.of(context)?.uiPreview ?? false)) ...[
          const Divider(height: 1, indent: 36),
          ProfileEntryRow(
            title: '退出当前应用',
            subtitle: '查看退出范围',
            icon: AppIcons.signOut,
            color: AppColors.red,
            onTap: () => _confirmLogout(context),
          ),
        ],
      ],
    ),
  );
}
