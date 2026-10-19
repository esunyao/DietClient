import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/demo/demo_store.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  void _preview(BuildContext context, ReportPreview report) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${report.title} / v${report.version}',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(report.period),
                const SizedBox(height: 12),
                Text('原版本记录日均：${formatAmount(report.average)} kcal'),
                const SizedBox(height: 12),
                Text(
                  report.stale
                      ? '原始记录已变化，此处保留原版本内容；请生成新版本查看更新摘要。'
                      : '当前版本的营养记录摘要。',
                ),
                const SizedBox(height: 12),
                const Text(
                  '本地演示报告，未经专业审核。记录日均不代表完整全天摄入；未填写或未分析的营养值不按零计算。未执行下载或分享。',
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: '关闭摘要',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoProvider);
    final latest = state.reports.first;
    final points = state.trend(7);
    final known = points
        .map((p) => p.nutrients.energy)
        .whereType<double>()
        .toList();
    final count = points.fold(0, (sum, point) => sum + point.recordCount);
    final analyzing = points.fold(
      0,
      (sum, point) => sum + point.analyzingCount,
    );
    return AppPage(
      title: '报告中心',
      subtitle: '设计样例 · 演示数据',
      showBack: true,
      footer: AppButton(
        label: '生成新报告（演示）',
        icon: Icons.description_outlined,
        onPressed: () {
          ref.read(demoProvider.notifier).generateReport();
          showDemoMessage(context, '已在内存中生成新的演示版本，历史版本保留原内容。');
        },
      ),
      children: [
        AdaptiveColumns(
          main: [
            AppCard(
              color: AppColors.greenSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    latest.title,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('${latest.period} / v${latest.version}'),
                  const SizedBox(height: 12),
                  AppBadge(label: latest.stale ? '数据已变化 · 需更新' : '参考报告，未经专业审核'),
                  const SizedBox(height: 16),
                  Text(
                    '${formatAmount(latest.average)} kcal',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text('原版本记录日均 · 固定样例日期 2026.10.02'),
                ],
              ),
            ),
            const SectionHeading(title: '本期摘要'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✓ 当前7天内有 ${known.length} 天存在可用能量记录'),
                  const SizedBox(height: 16),
                  Text('◷ 仍有 $analyzing 餐分析中'),
                  const SizedBox(height: 16),
                  const Text('记录日均不代表完整全天平均'),
                  const SizedBox(height: 20),
                  AppButton(
                    label: '查看完整摘要',
                    secondary: true,
                    onPressed: () => _preview(context, latest),
                  ),
                ],
              ),
            ),
            const SectionHeading(title: '历史与生成任务'),
            for (final report in state.reports)
              AppCard(
                child: AppListRow(
                  title: report.title,
                  subtitle: '${report.period} / v${report.version}',
                  leading: const Icon(Icons.description_outlined),
                  trailing: AppBadge(label: report.stale ? '需更新' : '查看版本'),
                  onTap: () => _preview(context, report),
                ),
              ),
          ],
          aside: [
            const SectionHeading(title: '完整摘要与口径'),
            AppCard(
              child: Text(
                '当前有数值的 ${known.length} 个记录日累计能量为 ${formatAmount(known.isEmpty ? null : known.reduce((a, b) => a + b))} kcal。\n\n餐食共 $count 条，包含 $analyzing 条分析中记录。\n\n日均以有数值的记录日为分母，不将缺失日或未知营养补零。\n\n本区为当前数据覆盖；查看历史版本时，原版本日均保持不变。',
              ),
            ),
            if (state.reports.any((report) => report.stale))
              const InfoBanner(
                color: AppColors.amberSoft,
                text: '旧报告数据已变化\n重新生成新版本，历史版本保留原内容。',
              ),
            const InfoBanner(text: '下载与分享前确认范围及授权\n当前仅提供本地摘要预览，不执行文件导出或外部分享。'),
          ],
        ),
      ],
    );
  }
}
