import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/demo/demo_store.dart';
import 'package:diet_client/core/presentation/app_routes.dart';

import '../widgets/health_kind.dart';

class HealthRecordsScreen extends ConsumerWidget {
  const HealthRecordsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoProvider);
    return AppPage(
      title: '健康档案',
      showBack: true,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${state.profile.name}的基础资料',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text('${state.profile.gender} / ${state.profile.birthday}'),
              const SizedBox(height: 8),
              Text(
                '身高 ${formatAmount(state.profile.height)} cm / ${state.profile.activity}',
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.push(AppRoutes.editProfile),
                child: const Text('编辑基础资料'),
              ),
            ],
          ),
        ),
        const SectionHeading(title: '五类健康记录'),
        for (final kind in healthKinds.keys)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppListRow(
                  title: healthKinds[kind]!,
                  subtitle: _summary(state.healthRecords, kind),
                  leading: Icon(
                    healthIcons[kind],
                    color: kind == 'allergy'
                        ? AppColors.amber
                        : AppColors.primary,
                  ),
                  onTap: () => context.push(AppRoutes.healthRecordForm(kind)),
                ),
                for (final record in state.healthRecords.where(
                  (r) => r.kind == kind,
                ))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${record.title} · ${record.value}'),
                    subtitle: Text(
                      '${record.date}${record.note.isEmpty ? '' : '\n${record.note}'}',
                    ),
                    isThreeLine: record.note.isNotEmpty,
                    trailing: IconButton(
                      tooltip: '删除演示记录',
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.red,
                      ),
                      onPressed: () async {
                        final remove = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('删除这条演示记录？'),
                            content: Text(
                              '“${record.title}”将从本次预览中移除，重启后恢复样例。',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('保留'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        );
                        if (remove == true) {
                          ref
                              .read(demoProvider.notifier)
                              .removeHealthRecord(record.id);
                          if (context.mounted)
                            showDemoMessage(context, '已从本次演示中移除。');
                        }
                      },
                    ),
                  ),
                TextButton(
                  onPressed: () =>
                      context.push(AppRoutes.healthRecordForm(kind)),
                  child: Text('添加${healthKinds[kind]}'),
                ),
              ],
            ),
          ),
        const SectionHeading(title: '资料与授权'),
        const InfoBanner(
          text: '资料录入与 AI 使用授权是两件事。未填写的过敏、疾病和饮食限制保持未知，不代表已确认没有。规则冲突时应由专业人员审核。',
        ),
        AppButton(
          label: '查看 AI 数据与隐私',
          secondary: true,
          onPressed: () => context.push(AppRoutes.aiConsent),
        ),
      ],
    );
  }

  String _summary(List<HealthRecordPreview> records, String kind) {
    final count = records.where((r) => r.kind == kind).length;
    return count == 0 ? '尚未填写，不代表已确认无相关情况' : '$count 条演示记录 · 可新增或移除';
  }
}
