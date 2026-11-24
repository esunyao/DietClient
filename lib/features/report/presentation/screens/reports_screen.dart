import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/ui_preview_config.dart';
import '../../../../core/presentation/unsupported_feature_page.dart';
import '../../../../demo/demo_store.dart';
import '../widgets/report_widgets.dart';

/// 营养报告页面，演示模式展示版本快照与覆盖概览，原生模式显示暂未支持。
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  void _preview(BuildContext context, ReportPreview report) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
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
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _generateReport(BuildContext context, WidgetRef ref) {
    ref.read(demoProvider.notifier).generateReport();
    showDemoMessage(context, '已在内存中生成新的演示版本，历史版本保留原内容。');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(nativeNutritionEnabledProvider)) {
      return const UnsupportedFeaturePage(
        title: '报告中心',
        description: '报告生成、历史版本与导出暂未支持。真实每日营养汇总已在首页和趋势中提供。',
      );
    }
    final state = ref.watch(demoProvider);
    final latest = state.reports.first;
    final history = state.reports.skip(1).toList();
    final points = state.trend(7);
    final known = points
        .map((p) => p.nutrients.energy)
        .whereType<double>()
        .toList();
    final total = known.isEmpty ? null : known.reduce((a, b) => a + b);
    final count = points.fold(0, (sum, point) => sum + point.recordCount);
    final analyzing = points.fold(
      0,
      (sum, point) => sum + point.analyzingCount,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1024;
        final historySection = _HistoryVersionSection(
          wide: wide,
          history: history,
          onTapReport: (report) => _preview(context, report),
        );
        final versionNotice = ReportVersionNotice(
          hasStale: state.reports.any((report) => report.stale),
          wide: wide,
        );
        final details = ReportCoverageDetails(
          total: total,
          knownDays: known.length,
          count: count,
          analyzing: analyzing,
          wide: wide,
        );

        return AppPage(
          demoLabel: '设计样例 · 演示数据',
          title: wide ? latest.title : '报告中心',
          subtitle: wide ? '${latest.period} · 参考报告，未经专业审核' : null,
          showBack: true,
          footer: _ReportFooter(
            wide: wide,
            canGenerate: known.isNotEmpty,
            onGenerate: () => _generateReport(context, ref),
          ),
          children: [
            AdaptiveColumns(
              main: [
                ReportOverview(
                  report: latest,
                  knownDays: known.length,
                  analyzing: analyzing,
                  wide: wide,
                ),
                if (!wide)
                  _NarrowPeriodSummarySection(
                    knownDays: known.length,
                    analyzing: analyzing,
                  ),
                AppButton(
                  label: '查看完整摘要',
                  secondary: true,
                  onPressed: () => _preview(context, latest),
                ),
                if (wide)
                  _WideEnergyOverviewSection(
                    points: points,
                    stale: latest.stale,
                  )
                else
                  historySection,
              ],
              aside: wide
                  ? [
                      historySection,
                      versionNotice,
                      const InfoBanner(
                        text: '分享前确认范围与授权\n当前仅本地摘要预览，不执行文件导出或外部分享。',
                      ),
                    ]
                  : const [],
            ),
            const SectionHeading(title: '完整摘要与口径'),
            if (wide) ReportDailyValues(points: points),
            details,
            if (!wide) ...[
              versionNotice,
              const InfoBanner(
                text: '下载与分享前确认范围及授权\n当前仅提供本地摘要预览，不执行文件导出或外部分享。',
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ReportFooter extends StatelessWidget {
  const _ReportFooter({
    required this.wide,
    required this.canGenerate,
    required this.onGenerate,
  });

  final bool wide;
  final bool canGenerate;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: SizedBox(
      width: wide ? 352 : double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            canGenerate ? '仅在本次演示中生成，不下载或分享' : '补充能量记录后可生成摘要',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: '生成新报告（演示）',
            icon: AppIcons.reports,
            onPressed: canGenerate ? onGenerate : null,
          ),
        ],
      ),
    ),
  );
}

class _HistoryVersionSection extends StatelessWidget {
  const _HistoryVersionSection({
    required this.wide,
    required this.history,
    required this.onTapReport,
  });

  final bool wide;
  final List<ReportPreview> history;
  final ValueChanged<ReportPreview> onTapReport;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeading(title: wide ? '历史版本' : '历史与生成任务'),
      const SizedBox(height: 14),
      for (var i = 0; i < history.length; i++) ...[
        ReportVersionCard(
          report: history[i],
          onTap: () => onTapReport(history[i]),
          wide: wide,
        ),
        if (i < history.length - 1) const SizedBox(height: 16),
      ],
      if (history.isEmpty) const AppCard(child: Text('尚无其他历史版本，生成后将在本次演示中保留。')),
    ],
  );
}

class _NarrowPeriodSummarySection extends StatelessWidget {
  const _NarrowPeriodSummarySection({
    required this.knownDays,
    required this.analyzing,
  });

  final int knownDays;
  final int analyzing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeading(title: '本期摘要'),
      const SizedBox(height: 14),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            ReportSummaryRow(
              icon: AppIcons.checkCircle,
              text: '当前7天内有 $knownDays 天存在可用能量记录',
            ),
            ReportSummaryRow(
              icon: AppIcons.history,
              text: analyzing > 0 ? '本周期仍有 $analyzing 餐分析中' : '本周期没有分析中的记录',
            ),
            const ReportSummaryRow(
              icon: AppIcons.warningCircle,
              text: '记录日均不代表完整全天平均',
              warning: true,
            ),
          ],
        ),
      ),
    ],
  );
}

class _WideEnergyOverviewSection extends StatelessWidget {
  const _WideEnergyOverviewSection({required this.points, required this.stale});

  final List<TrendPoint> points;
  final bool stale;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeading(title: '能量记录概览'),
      const SizedBox(height: 14),
      AppCard(
        radius: 16,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NutritionBarChart(
              values: points.map((p) => p.nutrients.energy).toList(),
              labels: points
                  .map((p) => '${p.date.month}/${p.date.day}')
                  .toList(),
              height: 210,
              highlightLast: true,
              showValueLabels: true,
              missingLabels: [
                for (final point in points)
                  point.recordCount == 0 ? '未记录' : '待补充',
              ],
            ),
            const SizedBox(height: 12),
            Text(
              stale ? '当前记录已变化，图表不是原报告快照；未知值不补零。' : '当前已知记录；缺失日期保持缺失，不补零。',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ],
  );
}
