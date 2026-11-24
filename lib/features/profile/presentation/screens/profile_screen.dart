import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/ui_preview_config.dart';
import '../../../../core/presentation/navigation_manager.dart';
import '../../../../demo/demo_store.dart';
import '../widgets/health_kind.dart';
import '../widgets/profile_cards.dart';
import '../widgets/profile_services.dart';
import 'real_profile_screen.dart';

/// “我的”主页面路由入口，按预览配置切换真实资料页或演示页面。
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(uiPreviewProvider)) return const RealProfileScreen();
    final state = ref.watch(demoProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final navigation = ref.read(navigationManagerProvider);

    final identity = ProfileIdentityCard(profile: state.profile, wide: wide);
    final health = ProfileHealthSummary(
      records: state.healthRecords,
      wide: wide,
    );
    final privacy = AppCard(
      radius: wide ? 16 : 20,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ProfileEntryRow(
        title: 'AI 数据与隐私',
        value: state.aiConsent ? '演示开关已开启' : '演示开关已关闭',
        icon: AppIcons.shield,
        onTap: () => navigation.openAiConsent(context),
      ),
    );

    return AppPage(
      demoLabel: '设计样例 · 演示数据',
      title: wide ? '你的资料与服务' : '我的',
      eyebrow: wide ? null : '资料与健康管理',
      subtitle: wide ? '个人档案与机构服务分开管理，健康资料按用途授权。' : null,
      children: [
        if (wide)
          AdaptiveColumns(
            main: [
              identity,
              ProfileSection(
                title: '健康档案',
                action: '查看全部',
                onTap: () => navigation.openHealthRecords(context),
                child: health,
              ),
              ProfileSection(
                title: '常用入口',
                child: ProfileServiceEntries(institution: state.isInstitution),
              ),
              ProfileSection(
                title: '基础资料',
                action: '编辑',
                onTap: () => navigation.openEditProfile(context),
                child: ProfileFactsCard(profile: state.profile),
              ),
            ],
            aside: [
              if (state.isInstitution) const ProfileInstitutionCard(),
              if (state.isInstitution) const ProfilePrivacyCard(),
              if (!state.isInstitution) privacy,
              const ProfileAccountCard(),
            ],
          )
        else
          _CompactDemoProfileBody(
            identity: identity,
            profile: state.profile,
            health: health,
            privacy: privacy,
            institution: state.isInstitution,
            onOpenEditProfile: () => navigation.openEditProfile(context),
            onOpenHealthRecords: () => navigation.openHealthRecords(context),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '当前档案为演示人物资料\n资料未填写，不等于已确认无相关健康限制。修改仅保留在本次内存预览。',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.8),
          ),
        ),
      ],
    );
  }
}

class _CompactDemoProfileBody extends StatelessWidget {
  const _CompactDemoProfileBody({
    required this.identity,
    required this.profile,
    required this.health,
    required this.privacy,
    required this.institution,
    required this.onOpenEditProfile,
    required this.onOpenHealthRecords,
  });

  final Widget identity;
  final PersonProfile profile;
  final Widget health;
  final Widget privacy;
  final bool institution;
  final VoidCallback onOpenEditProfile;
  final VoidCallback onOpenHealthRecords;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      identity,
      const SizedBox(height: 14),
      const ProfileShortcuts(),
      const SizedBox(height: 12),
      ProfileSection(
        title: '基础资料',
        action: '编辑',
        onTap: onOpenEditProfile,
        child: ProfileFactsCard(profile: profile),
      ),
      const SizedBox(height: 16),
      ProfileSection(
        title: '健康资料',
        action: '管理',
        onTap: onOpenHealthRecords,
        child: health,
      ),
      const SizedBox(height: 16),
      privacy,
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Text(
          '查看分析用途；演示开关不构成真实授权',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ),
      if (institution) ...[
        const ProfileInstitutionCard(),
        const SizedBox(height: 16),
        const ProfilePrivacyCard(),
        const SizedBox(height: 16),
      ],
      const ProfileSection(title: '账户与帮助', child: ProfileAccountCard()),
    ],
  );
}

/// 资料页面通用分节容器，统一展示标题与可选操作入口。
class ProfileSection extends StatelessWidget {
  const ProfileSection({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.onTap,
  });

  final String title;
  final Widget child;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeading(title: title, detail: action, onTap: onTap),
      const SizedBox(height: 10),
      child,
    ],
  );
}

/// 资料页窄屏快捷入口栏，提供健康档案、营养报告与饮食历史入口。
class ProfileShortcuts extends ConsumerWidget {
  const ProfileShortcuts({super.key});

  void _openShortcut(BuildContext context, WidgetRef ref, int index) {
    final navigation = ref.read(navigationManagerProvider);
    switch (index) {
      case 0:
        navigation.openHealthRecords(context);
      case 1:
        navigation.openReports(context);
      case 2:
        navigation.openMealHistory(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const entries = [
      (label: '健康档案', icon: AppIcons.identification),
      (label: '我的报告', icon: AppIcons.reports),
      (label: '饮食历史', icon: AppIcons.history),
    ];
    return Row(
      children: [
        for (var i = 0; i < entries.length; i++)
          Expanded(
            child: TextButton(
              onPressed: () => _openShortcut(context, ref, i),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(entries[i].icon, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    entries[i].label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
