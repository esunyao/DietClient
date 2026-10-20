import 'package:flutter/material.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/demo/demo_store.dart';

class ReportSummaryRow extends StatelessWidget {
  const ReportSummaryRow({
    super.key,
    required this.icon,
    required this.text,
    this.warning = false,
    this.wide = false,
  });

  final IconData icon;
  final String text;
  final bool warning;
  final bool wide;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: warning ? AppColors.amberInk : AppColors.primary,
          size: 22,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: wide ? 16 : 14, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class ReportVersionCard extends StatelessWidget {
  const ReportVersionCard({
    super.key,
    required this.report,
    required this.onTap,
    required this.wide,
  });

  final ReportPreview report;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: wide ? 16 : 20,
    padding: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: wide ? 24 : 20,
          vertical: wide ? 24 : 15,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inlineBadge =
                !wide &&
                constraints.maxWidth >= 300 &&
                MediaQuery.textScalerOf(context).scale(13) <= 18;
            final badge = AppBadge(
              label: report.stale
                  ? wide
                        ? '数据变化，需更新'
                        : '需更新'
                  : wide
                  ? '原版本保留'
                  : '查看版本',
              color: report.stale ? AppColors.amberInk : AppColors.primary,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      AppIcons.reports,
                      size: 25,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.title,
                            style: TextStyle(
                              fontSize: wide ? 16 : 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!wide) ...[
                            const SizedBox(height: 5),
                            Text(
                              '${report.period} / v${report.version}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (inlineBadge) ...[const SizedBox(width: 12), badge],
                  ],
                ),
                if (wide) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${report.period} / v${report.version}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.muted,
                    ),
                  ),
                ],
                if (!inlineBadge) ...[
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: badge),
                ],
                if (wide) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onTap,
                      child: const Text('查看原版本'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );
}

class ReportOverview extends StatelessWidget {
  const ReportOverview({
    super.key,
    required this.report,
    required this.knownDays,
    required this.analyzing,
    required this.wide,
  });

  final ReportPreview report;
  final int knownDays;
  final int analyzing;
  final bool wide;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: wide ? 16 : 20,
    color: wide ? AppColors.surface : AppColors.greenSoft,
    padding: EdgeInsets.all(wide ? 24 : 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (!wide) ...[
              const Icon(AppIcons.reports, color: AppColors.primary, size: 31),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Text(
                wide ? '本期摘要' : report.title,
                style: TextStyle(
                  fontSize: wide ? 20 : 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (wide) const AppBadge(label: '报告演示'),
          ],
        ),
        if (!wide) ...[
          const SizedBox(height: 12),
          Text(
            '${report.period} / v${report.version}',
            style: const TextStyle(fontSize: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: AppBadge(
              label: report.stale ? '数据已变化 · 需更新' : '参考报告，未经专业审核',
              color: report.stale ? AppColors.amberInk : AppColors.primary,
            ),
          ),
        ],
        SizedBox(height: wide ? 14 : 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final average = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatAmount(report.average),
                  style: TextStyle(
                    fontSize: wide ? 38 : 29,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${report.stale ? '原版本 ' : ''}kcal / 记录日均',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            );
            final coverage = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wide ? '$knownDays / 7' : '$knownDays',
                  style: TextStyle(
                    fontSize: wide ? 30 : 29,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  '当前有数值记录日',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            );
            final stack =
                constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(14) > 20;
            return Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: stack
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 24) / 2,
                  child: wide ? average : coverage,
                ),
                SizedBox(
                  width: stack
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 24) / 2,
                  child: wide ? coverage : average,
                ),
              ],
            );
          },
        ),
        if (wide) ...[
          const Divider(height: 28, color: AppColors.line),
          ReportSummaryRow(
            icon: AppIcons.checkCircle,
            text: '当前7天内有 $knownDays 天可用于能量汇总',
            wide: true,
          ),
          ReportSummaryRow(
            icon: AppIcons.history,
            text: analyzing > 0 ? '本周期仍有 $analyzing 餐分析中' : '本周期没有分析中的记录',
            warning: analyzing > 0,
            wide: true,
          ),
          const SizedBox(height: 6),
          const Text(
            '报告仅覆盖已知记录，不代表完整全天摄入',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ] else ...[
          const SizedBox(height: 12),
          const Text(
            '固定演示日期 2026.10.02',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
        if (report.stale) ...[
          const SizedBox(height: 10),
          const Text(
            '日均保留原版本；当前覆盖与下方图表可能已变化。',
            style: TextStyle(fontSize: 12, color: AppColors.amberInk),
          ),
        ],
      ],
    ),
  );
}

class ReportVersionNotice extends StatelessWidget {
  const ReportVersionNotice({
    super.key,
    required this.hasStale,
    required this.wide,
  });
  final bool hasStale;
  final bool wide;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: 16,
    color: AppColors.greenSoft,
    padding: EdgeInsets.all(wide ? 24 : 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '更新保留历史版本',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '修正餐食后，旧报告标记需更新。重新生成新版本，保留原版本日均。',
          style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.7),
        ),
        if (hasStale) ...[
          const SizedBox(height: 12),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.warningCircle, color: AppColors.amberInk, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '存在数据已变化的旧报告',
                  style: TextStyle(fontSize: 13, color: AppColors.amberInk),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class ReportCoverageDetails extends StatelessWidget {
  const ReportCoverageDetails({
    super.key,
    required this.total,
    required this.knownDays,
    required this.count,
    required this.analyzing,
    required this.wide,
  });
  final double? total;
  final int knownDays;
  final int count;
  final int analyzing;
  final bool wide;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: wide ? 16 : 20,
    padding: EdgeInsets.all(wide ? 24 : 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '当前有数值的 $knownDays 个记录日累计能量为 ${formatAmount(total)} kcal。',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.muted,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '餐食共 $count 条，包含 $analyzing 条分析中记录。',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.muted,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '日均以有数值的记录日为分母，不将缺失日或未知营养补零；计划与待确认机构餐食不入账。',
          style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.7),
        ),
        const SizedBox(height: 12),
        const Text(
          '本区为当前数据覆盖；查看历史版本时，原版本日均保持不变。',
          style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.7),
        ),
      ],
    ),
  );
}

class ReportDailyValues extends StatelessWidget {
  const ReportDailyValues({super.key, required this.points});
  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: const Text('查看逐日数值', style: TextStyle(fontSize: 14)),
    children: [
      for (final point in points)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${point.date.month}月${point.date.day}日',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(
                point.nutrients.energy == null
                    ? point.recordCount == 0
                          ? '未记录'
                          : '待补充'
                    : '${formatAmount(point.nutrients.energy)} kcal',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
        ),
    ],
  );
}
