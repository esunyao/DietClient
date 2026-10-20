import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/ui_preview_config.dart';
import 'real_profile_screen.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/presentation/app_routes.dart';
import '../../../../demo/demo_store.dart';
import '../widgets/health_kind.dart';
import '../widgets/profile_cards.dart';
import '../widgets/profile_services.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(uiPreviewProvider)) return const RealProfileScreen();
    final state = ref.watch(demoProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1024;
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
        onTap: () => context.push(AppRoutes.aiConsent),
      ),
    );
    return AppPage(
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
                onTap: () => context.push(AppRoutes.healthRecords),
                child: health,
              ),
              ProfileSection(
                title: '常用入口',
                child: ProfileServiceEntries(institution: state.isInstitution),
              ),
              ProfileSection(
                title: '基础资料',
                action: '编辑',
                onTap: () => context.push(AppRoutes.editProfile),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              const SizedBox(height: 14),
              const ProfileShortcuts(),
              const SizedBox(height: 12),
              ProfileSection(
                title: '基础资料',
                action: '编辑',
                onTap: () => context.push(AppRoutes.editProfile),
                child: ProfileFactsCard(profile: state.profile),
              ),
              const SizedBox(height: 16),
              ProfileSection(
                title: '健康资料',
                action: '管理',
                onTap: () => context.push(AppRoutes.healthRecords),
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
              if (state.isInstitution) ...[
                const ProfileInstitutionCard(),
                const SizedBox(height: 16),
                const ProfilePrivacyCard(),
                const SizedBox(height: 16),
              ],
              const ProfileSection(title: '账户与帮助', child: ProfileAccountCard()),
            ],
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

class ProfileShortcuts extends StatelessWidget {
  const ProfileShortcuts({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final entry in [
        (
          label: '健康档案',
          icon: AppIcons.identification,
          route: AppRoutes.healthRecords,
        ),
        (label: '我的报告', icon: AppIcons.reports, route: AppRoutes.reports),
        (label: '饮食历史', icon: AppIcons.history, route: AppRoutes.mealHistory),
      ])
        Expanded(
          child: TextButton(
            onPressed: () => context.push(entry.route),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(entry.icon, size: 28),
                const SizedBox(height: 8),
                Text(
                  entry.label,
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
