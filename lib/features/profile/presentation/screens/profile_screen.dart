import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/demo/demo_store.dart';
import 'package:diet_client/core/presentation/app_routes.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoProvider);
    final profile = state.profile;
    HealthRecordPreview? latestMeasurement;
    for (final record in state.healthRecords.where(
      (r) => r.kind == 'measurement',
    )) {
      if (latestMeasurement == null ||
          record.date.compareTo(latestMeasurement.date) >= 0) {
        latestMeasurement = record;
      }
    }
    final goals = state.healthRecords.where((r) => r.kind == 'goal');
    final allergies = state.healthRecords.where((r) => r.kind == 'allergy');
    Widget row(String title, String value, IconData icon) => AppListRow(
      title: title,
      subtitle: value,
      leading: Icon(icon, color: AppColors.primary),
    );
    final facts = AppCard(
      child: Column(
        children: [
          row('出生日期', profile.birthday, Icons.calendar_today_outlined),
          row(
            '身高与活动',
            '${formatAmount(profile.height)} cm / ${profile.activity}',
            Icons.accessibility_new_outlined,
          ),
          row(
            '饮水目标',
            '${profile.waterGoal} ml / 用户设置',
            Icons.water_drop_outlined,
          ),
          const Text('基础资料与身体测量分别保留', style: TextStyle(color: AppColors.muted)),
        ],
      ),
    );
    final health = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('最近身体测量', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 8),
          Text(
            latestMeasurement?.value ?? '暂未填写',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (latestMeasurement != null)
            Text(
              '${latestMeasurement.title} / ${latestMeasurement.date}',
              style: const TextStyle(color: AppColors.muted),
            ),
          const Divider(height: 28),
          Text(
            '健康目标：${goals.isEmpty ? '暂未填写' : goals.map((r) => r.value).join('、')}',
          ),
          const SizedBox(height: 8),
          Text(
            '过敏：${allergies.isEmpty ? '尚未填写' : allergies.map((r) => r.title).join('、')}',
          ),
        ],
      ),
    );
    return AppPage(
      title: '我的',
      subtitle: '资料与健康管理',
      children: [
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AvatarIllustration(size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(profile.email),
                    const SizedBox(height: 12),
                    const AppBadge(label: '演示身份'),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.editProfile),
                      child: const Text('编辑资料'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          children: [
            _QuickLink(
              label: '健康档案',
              icon: Icons.badge_outlined,
              onTap: () => context.push(AppRoutes.healthRecords),
            ),
            _QuickLink(
              label: '我的报告',
              icon: Icons.description_outlined,
              onTap: () => context.push(AppRoutes.reports),
            ),
            _QuickLink(
              label: '饮食历史',
              icon: Icons.history,
              onTap: () => context.push(AppRoutes.mealHistory),
            ),
          ],
        ),
        AdaptiveColumns(
          main: [
            SectionHeading(
              title: '基础资料',
              detail: '编辑',
              onTap: () => context.push(AppRoutes.editProfile),
            ),
            facts,
            SectionHeading(
              title: '健康资料',
              detail: '管理',
              onTap: () => context.push(AppRoutes.healthRecords),
            ),
            health,
          ],
          aside: [
            AppCard(
              child: AppListRow(
                title: 'AI 数据与隐私',
                subtitle: state.aiConsent ? '演示开关已开启' : '演示开关已关闭',
                leading: const Icon(Icons.verified_user_outlined),
                onTap: () => context.push(AppRoutes.aiConsent),
              ),
            ),
            if (state.isInstitution)
              AppCard(
                color: AppColors.greenSoft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeading(title: '机构服务'),
                    const Text('医疗院 · 一号食堂（虚构机构）'),
                    const SizedBox(height: 12),
                    AppButton(
                      label: '机构餐食同步',
                      secondary: true,
                      onPressed: () => context.push(AppRoutes.institutionSync),
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.institutionMenu),
                      child: const Text('查看食堂菜单'),
                    ),
                  ],
                ),
              ),
            const SectionHeading(title: '账户与帮助'),
            AppCard(
              child: Column(
                children: [
                  AppListRow(
                    title: '应用设置',
                    subtitle: '显示、体验模式与帮助',
                    leading: const Icon(Icons.settings_outlined),
                    onTap: () => context.push(AppRoutes.settings),
                  ),
                  AppListRow(
                    title: '账号流程预览',
                    subtitle: '登录、注册与邮箱验证',
                    leading: const Icon(Icons.login),
                    onTap: () => context.push(AppRoutes.login),
                  ),
                ],
              ),
            ),
          ],
        ),
        const InfoBanner(text: '资料未填写，不等于已确认无相关健康限制。所有资料修改仅用于本次内存演示。'),
      ],
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 28), const SizedBox(height: 8), Text(label)],
    ),
  );
}
