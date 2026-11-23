import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/app_routes.dart';
import '../../../../demo/demo_store.dart';
import 'health_kind.dart';

/// 共享身份卡；调用方可替换默认演示头像、身份标签和缺失身高的展示文本。
class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({
    super.key,
    required this.profile,
    this.wide = false,
    this.avatar,
    this.identityLabel = '演示身份',
    this.heightLabel,
  });

  final PersonProfile profile;
  final bool wide;
  final Widget? avatar;
  final String identityLabel;
  final String? heightLabel;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: wide ? 16 : 20,
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: wide ? 24 : 16),
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: wide ? 102 : 98),
      child: Row(
        children: [
          avatar ?? AvatarIllustration(size: wide ? 76 : 65),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  profile.email,
                  style: TextStyle(
                    fontSize: wide ? 15 : 13,
                    color: AppColors.muted,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                if (wide)
                  AppBadge(label: identityLabel)
                else
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        AppBadge(label: identityLabel),
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
          if (wide) ...[
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => context.push(AppRoutes.editProfile),
                    child: const Text('编辑基础资料'),
                  ),
                  Text(
                    '${profile.gender} · ${profile.birthday}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${heightLabel ?? '${formatAmount(profile.height)} cm'} · ${profile.activity}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// 展示基础资料；身高和饮水标签可由调用方覆盖，以表达真实数据缺失。
class ProfileFactsCard extends StatelessWidget {
  const ProfileFactsCard({
    super.key,
    required this.profile,
    this.heightLabel,
    this.waterLabel,
  });

  final PersonProfile profile;
  final String? heightLabel, waterLabel;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FactRow(
          icon: AppIcons.calendar,
          label: '出生日期',
          value: profile.birthday,
        ),
        const Divider(height: 1, indent: 36),
        _FactRow(
          icon: AppIcons.profile,
          label: '身高与活动',
          value:
              '${heightLabel ?? '${formatAmount(profile.height)} cm'} / ${profile.activity}',
        ),
        const Divider(height: 1, indent: 36),
        _FactRow(
          icon: AppIcons.drop,
          label: '饮水目标',
          value: waterLabel ?? '${profile.waterGoal} ml / 用户设置',
        ),
        const SizedBox(height: 10),
        const Text(
          '身体测量按日期保留，不覆盖历史记录',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

/// 从传入的真实或演示摘要记录中组合最近测量、目标及过敏和缺失提示。
class ProfileHealthSummary extends StatelessWidget {
  const ProfileHealthSummary({
    super.key,
    required this.records,
    this.wide = false,
    this.real = false,
  });

  final List<HealthRecordPreview> records;
  final bool wide;
  final bool real;

  @override
  Widget build(BuildContext context) {
    final measurement = latestHealthRecord(records, 'measurement');
    final goal = latestHealthRecord(records, 'goal');
    final allergies = records.where((r) => r.kind == 'allergy').toList();
    final allergySummary = allergies.isEmpty
        ? '过敏：尚未填写'
        : '过敏：${allergies.first.title}${allergies.length > 1 ? '等${allergies.length}项' : ''} / 已登记';
    final missing = [
      if (!records.any((r) => r.kind == 'disease')) '疾病',
      if (!records.any((r) => r.kind == 'restriction')) '饮食限制',
    ];
    Widget summary(
      String label,
      String value,
      String detail, {
      required double valueSize,
      IconData? icon,
    }) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wide && icon != null) ...[
          Icon(icon, size: 27, color: AppColors.primary),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return AppCard(
      radius: wide ? 16 : 20,
      padding: EdgeInsets.all(wide ? 24 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final items = [
                summary(
                  measurement == null
                      ? '最近身体测量'
                      : '最近${measurement.title.split('（').first}',
                  measurement?.value ?? '暂未填写',
                  measurement == null
                      ? '添加测量后查看'
                      : '${healthRecordDate(measurement.date)}${real ? '' : ' / 手工测量'}',
                  valueSize: wide ? 28 : 23,
                  icon: AppIcons.scales,
                ),
                summary(
                  wide ? '当前目标' : '健康目标',
                  goal?.value ?? '暂未填写',
                  allergySummary,
                  valueSize: wide ? 24 : 19,
                  icon: AppIcons.target,
                ),
              ];
              // 按卡片实际宽度和文字缩放决定摘要横排或纵排。
              if (constraints.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    items.first,
                    const Divider(height: 28),
                    items.last,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: items.first),
                  SizedBox(width: wide ? 40 : 16),
                  Expanded(child: items.last),
                ],
              );
            },
          ),
          if (wide && missing.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              '${missing.join('与')}尚未填写，保持未知',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 50),
    child: Row(
      children: [
        Icon(icon, size: 24, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 基础资料行独立按剩余宽度和文字缩放切换紧凑布局。
              final compact =
                  constraints.maxWidth < 260 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20;
              if (compact) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Row(
                children: [
                  Text(label, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
