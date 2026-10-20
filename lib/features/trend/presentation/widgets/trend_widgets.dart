import 'package:flutter/material.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/demo/demo_store.dart';

class TrendCoverage extends StatelessWidget {
  const TrendCoverage({
    super.key,
    required this.knownDays,
    required this.days,
    required this.records,
    required this.analyzing,
    required this.wide,
  });

  final int knownDays;
  final int days;
  final int records;
  final int analyzing;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return AppCard(
        radius: 16,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '数据完整度',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 32,
              runSpacing: 8,
              children: [
                Text('有数值记录日 $knownDays / $days'),
                Text('餐食 $records 条'),
                Text('$analyzing 条分析中'),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '缺失日期保持缺失；当前数据不代表完整全天摄入',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 21;
        final width = stacked
            ? constraints.maxWidth
            : (constraints.maxWidth - 14) / 2;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final metric in [
              (label: '有数值记录日', value: '$knownDays / $days', unit: ''),
              (label: '餐食记录', value: '$records', unit: '餐'),
            ])
              SizedBox(
                width: width,
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 19,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metric.label,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            metric.value,
                            style: const TextStyle(
                              fontSize: 26,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (metric.unit.isNotEmpty)
                            Text(
                              metric.unit,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class TrendDailyTable extends StatelessWidget {
  const TrendDailyTable({
    super.key,
    required this.points,
    required this.code,
    required this.unit,
    required this.wide,
  });

  final List<TrendPoint> points;
  final String code;
  final String unit;
  final bool wide;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: wide ? 16 : 20,
    padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 20, vertical: 8),
    child: Column(
      children: [
        for (var i = 0; i < points.length; i++) ...[
          Builder(
            builder: (context) {
              final point = points[i];
              final value = point.nutrients.value(code);
              final coverage = point.recordCount == 0
                  ? '没有餐食记录'
                  : '${point.recordCount} 餐记录${point.analyzingCount > 0 ? ' / ${point.analyzingCount} 餐分析中' : ''}';
              return Semantics(
                container: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked =
                          constraints.maxWidth < 320 ||
                          MediaQuery.textScalerOf(context).scale(13) > 18;
                      final amount = Text(
                        value == null
                            ? point.recordCount == 0
                                  ? '未记录'
                                  : '待补充'
                            : '${formatAmount(value)} $unit',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: wide ? 150 : 78,
                                child: Text(
                                  '${point.date.month}月${point.date.day}日',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  coverage,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                              if (!stacked) ...[
                                const SizedBox(width: 12),
                                amount,
                              ],
                            ],
                          ),
                          if (stacked) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: amount,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
          if (i < points.length - 1)
            const Divider(height: 1, color: AppColors.line),
        ],
      ],
    ),
  );
}

class TrendReadingGuide extends StatelessWidget {
  const TrendReadingGuide({super.key, required this.label, required this.wide});

  final String label;
  final bool wide;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: wide ? 16 : 20,
    color: wide ? AppColors.greenSoft : null,
    padding: EdgeInsets.all(wide ? 24 : 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (wide) ...[
              const Icon(AppIcons.trends, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
            ],
            const Expanded(
              child: Text(
                '怎样读这张图',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          wide
              ? '展示记录中的$label变化。不把记录日均视为全天摄入平均，也不推断营养达标率。'
              : '图表汇总已知$label值，不代表每天完整摄入。缺少该指标的记录日不进入均值分母。\n身体测量与营养摄入采用不同来源和口径。',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.muted,
            height: 1.7,
          ),
        ),
      ],
    ),
  );
}

class TrendReportEntry extends StatelessWidget {
  const TrendReportEntry({super.key, required this.wide, required this.onTap});

  final bool wide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: wide ? 16 : 20,
    padding: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(wide ? 24 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  AppIcons.reports,
                  color: AppColors.primary,
                  size: 29,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wide ? '本周营养记录报告' : '本周营养报告',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!wide) ...[
                        const SizedBox(height: 5),
                        const Text(
                          '查看数据覆盖、来源与阶段摘要',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!wide)
                  const Icon(
                    AppIcons.chevronRight,
                    color: AppColors.primary,
                    size: 20,
                  ),
              ],
            ),
            if (wide) ...[
              const SizedBox(height: 16),
              const Text(
                '查看摘要、覆盖范围和历史版本',
                style: TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              AppButton(label: '查看报告', secondary: true, onPressed: onTap),
            ],
          ],
        ),
      ),
    ),
  );
}

class TrendAverageCard extends StatelessWidget {
  const TrendAverageCard({
    super.key,
    required this.average,
    required this.total,
    required this.knownDays,
    required this.days,
    required this.unit,
  });

  final double? average;
  final double? total;
  final int knownDays;
  final int days;
  final String unit;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: 16,
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '有数值记录日均',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              formatAmount(average?.roundToDouble()),
              style: const TextStyle(
                fontSize: 39,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            Text(
              unit,
              style: const TextStyle(fontSize: 14, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          knownDays == 0
              ? '暂无可用数值，日均待补充'
              : '合计 ${formatAmount(total)} $unit ÷ $knownDays 个记录日',
          style: const TextStyle(fontSize: 14, color: AppColors.muted),
        ),
        const Divider(height: 24, color: AppColors.line),
        Text(
          knownDays == days ? '每天均有该指标的记录值' : '${days - knownDays} 天缺少该营养素数值',
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 8),
        const Text(
          '不补零，不参与日均分母',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class TrendCoverageNotice extends StatelessWidget {
  const TrendCoverageNotice({super.key, required this.analyzing});
  final int analyzing;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: 16,
    color: AppColors.greenSoft,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(AppIcons.warningCircle, color: AppColors.primary, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '当前为记录日均值',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '缺失日不补零${analyzing > 0 ? '，本周期仍有 $analyzing 餐分析中' : '，仅统计已知营养'}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
