import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/ui_preview_config.dart';
import 'real_health_records_screen.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/presentation/app_routes.dart';
import '../../../../demo/demo_store.dart';
import '../widgets/health_kind.dart';
import '../widgets/health_record_category.dart';

class HealthRecordsScreen extends ConsumerWidget {
  const HealthRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(uiPreviewProvider)) return const RealHealthRecordsScreen();
    final state = ref.watch(demoProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final profile = state.profile;
    final basics = AppCard(
      radius: wide ? 16 : 20,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wide)
            Row(
              children: [
                Expanded(
                  child: Text(
                    profile.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.editProfile),
                  child: const Text('编辑基础资料'),
                ),
              ],
            )
          else
            Text(
              '${profile.name}的基础资料',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          const SizedBox(height: 10),
          Text(
            '${profile.gender} / ${profile.birthday}${wide ? ' / 身高 ${formatAmount(profile.height)} cm / ${profile.activity}' : ''}',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (!wide) ...[
            const SizedBox(height: 8),
            Text(
              '身高 ${formatAmount(profile.height)} cm / ${profile.activity}',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '基础资料与身体测量分开保留',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
              if (!wide)
                TextButton(
                  onPressed: () => context.push(AppRoutes.editProfile),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: const Text('编辑'),
                ),
            ],
          ),
        ],
      ),
    );
    final categories = [
      for (final kind in healthKinds.keys)
        HealthRecordCategory(
          key: ValueKey(kind),
          kind: kind,
          records: state.healthRecords.where((r) => r.kind == kind).toList(),
          wide: wide,
        ),
    ];
    final records = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading(title: '五类健康记录'),
        const SizedBox(height: 16),
        if (wide)
          AppCard(
            radius: 16,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < categories.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 68, endIndent: 24),
                  categories[i],
                ],
              ],
            ),
          )
        else
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            AppCard(radius: 16, padding: EdgeInsets.zero, child: categories[i]),
          ],
      ],
    );
    final usage = AppCard(
      radius: wide ? 16 : 20,
      color: AppColors.greenSoft,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wide ? '资料用于什么' : '资料与授权',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '身体测量用于查看变化。\n目标与偏好用于方案筛选。\n过敏与限制用于提示冲突。\n资料录入与 AI 使用授权分别管理。',
            style: TextStyle(fontSize: 14, height: 2, color: AppColors.ink),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.push(AppRoutes.aiConsent),
            child: const Text('查看 AI 数据与隐私'),
          ),
        ],
      ),
    );
    return AppPage(
      title: wide ? '让建议建立在真实资料上' : '健康档案',
      subtitle: wide ? '基础身份与历史健康记录分开保留，未填写的信息保持未知。' : null,
      showBack: true,
      children: [
        if (wide)
          AdaptiveColumns(
            main: [basics, records],
            aside: [
              usage,
              const AppCard(
                radius: 16,
                color: AppColors.greenSoft,
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '未知，不能当作没有',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '疾病未填写、限制暂无记录，都保持未知。不能自动标记为已确认无。',
                      style: TextStyle(fontSize: 14, height: 1.7),
                    ),
                  ],
                ),
              ),
              const AppCard(
                radius: 16,
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(AppIcons.shield, size: 28, color: AppColors.primary),
                    SizedBox(height: 12),
                    Text(
                      '敏感资料逐步展开',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '列表只展示必要摘要；点击类别后再查看、添加或移除演示记录。',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        else ...[
          basics,
          const SizedBox(height: 8),
          records,
          const SizedBox(height: 24),
          usage,
        ],
        const Text(
          '未填写的过敏、疾病和饮食限制不代表已确认没有。规则冲突时应由专业人员审核；本次预览不会授予真实数据访问权限。',
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.7),
        ),
      ],
    );
  }
}
