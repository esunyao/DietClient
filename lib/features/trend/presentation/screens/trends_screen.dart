import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/core/presentation/app_routes.dart';
import 'package:diet_client/demo/demo_store.dart';

import '../widgets/trend_widgets.dart';

class TrendsScreen extends ConsumerStatefulWidget {
  const TrendsScreen({super.key});
  @override
  ConsumerState<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends ConsumerState<TrendsScreen> {
  int _range = 0;
  int _nutrient = 0;
  static const _nutrients = [
    (code: 'energy', label: '能量', unit: 'kcal'),
    (code: 'protein', label: '蛋白质', unit: 'g'),
    (code: 'carbs', label: '碳水', unit: 'g'),
    (code: 'fat', label: '脂肪', unit: 'g'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(demoProvider);
    final days = [7, 30, 90][_range];
    final points = state.trend(days);
    final nutrient = _nutrients[_nutrient];
    final values = points.map((p) => p.nutrients.value(nutrient.code)).toList();
    final known = values.whereType<double>().toList();
    final total = known.isEmpty ? null : known.reduce((a, b) => a + b);
    final average = total == null ? null : total / known.length;
    final records = points.fold(0, (sum, point) => sum + point.recordCount);
    final analyzing = points.fold(
      0,
      (sum, point) => sum + point.analyzingCount,
    );
    final labels = points.map((p) => '${p.date.month}/${p.date.day}').toList();
    final period =
        '${points.first.date.month}月${points.first.date.day}日 — ${points.last.date.month}月${points.last.date.day}日';
    final rangeSelector = AppSegmented(
      labels: const ['7 日', '30 日', '90 日'],
      equalWidth: true,
      selected: _range,
      onChanged: (value) => setState(() => _range = value),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1024;
        final nutrientSelector = AppSegmented(
          labels: _nutrients.map((value) => value.label).toList(),
          selected: _nutrient,
          onChanged: (value) => setState(() => _nutrient = value),
          equalWidth: true,
          selectedFilled: !wide,
        );
        final chart = AppCard(
          radius: wide ? 16 : 20,
          padding: EdgeInsets.all(wide ? 24 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text(
                    wide ? '每日已记录${nutrient.label}' : '${nutrient.label}每日变化',
                    style: TextStyle(
                      fontSize: wide ? 20 : 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    wide
                        ? nutrient.unit
                        : '日均 ${formatAmount(average?.roundToDouble())}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: wide ? FontWeight.w400 : FontWeight.w600,
                      color: wide ? AppColors.muted : AppColors.primary,
                    ),
                  ),
                ],
              ),
              if (!wide) ...[
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      period,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    Text(
                      '${nutrient.unit} / 有数值的记录日',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              NutritionBarChart(
                values: values,
                labels: labels,
                unit: nutrient.unit,
                height: wide ? 266 : 186,
                highlightLast: true,
                showValueLabels: days == 7,
                missingLabels: [
                  for (final point in points)
                    point.recordCount == 0 ? '未记录' : '待补充',
                ],
              ),
              if (wide) ...[
                const SizedBox(height: 12),
                Text(
                  analyzing > 0 ? '本周期仍有 $analyzing 餐分析中' : '仅汇总已知营养值',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ],
          ),
        );
        final coverage = TrendCoverage(
          knownDays: known.length,
          days: days,
          records: records,
          analyzing: analyzing,
          wide: wide,
        );
        final readingGuide = TrendReadingGuide(
          label: nutrient.label,
          wide: wide,
        );
        final reportEntry = TrendReportEntry(
          wide: wide,
          onTap: () => context.push(AppRoutes.reports),
        );
        return AppPage(
          title: wide ? '看记录中的营养变化' : '营养趋势',
          eyebrow: wide ? null : '看记录中的变化',
          subtitle: wide ? '$period · 只比较有已知数值的记录' : null,
          children: [
            AdaptiveColumns(
              main: [
                if (wide)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 700 ||
                          MediaQuery.textScalerOf(context).scale(14) > 20) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            rangeSelector,
                            const SizedBox(height: 12),
                            nutrientSelector,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 246, child: rangeSelector),
                          const SizedBox(width: 24),
                          Expanded(child: nutrientSelector),
                        ],
                      );
                    },
                  )
                else ...[
                  rangeSelector,
                  nutrientSelector,
                ],
                chart,
                coverage,
                if (!wide) ...[
                  TrendCoverageNotice(analyzing: analyzing),
                  reportEntry,
                ],
              ],
              aside: wide
                  ? [
                      TrendAverageCard(
                        average: average,
                        total: total,
                        knownDays: known.length,
                        days: days,
                        unit: nutrient.unit,
                      ),
                      readingGuide,
                      reportEntry,
                    ]
                  : const [],
            ),
            const SizedBox(height: 4),
            const SectionHeading(title: '逐日记录概况'),
            TrendDailyTable(
              points: points,
              code: nutrient.code,
              unit: nutrient.unit,
              wide: wide,
            ),
            if (!wide) readingGuide,
          ],
        );
      },
    );
  }
}
