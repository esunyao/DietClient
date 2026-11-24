import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/nutrition/application/nutrition_providers.dart';
import '../../../../core/presentation/current_date.dart';

String _formatTrendAmount(double? value) =>
    value == null ? '未知' : value.toStringAsFixed(1);

/// 提取单日已记录营养值；空日期及零餐次日期保持 `null`，不按零补齐。
double? recordedNutrient(DailySummary? day, String code) =>
    day == null || day.mealCount == 0
    ? null
    : nutrientAmount(day.nutrients, code);

/// 原生真实营养趋势页面，按共享本地日期窗口查询并展示多日趋势。
class NativeTrendsScreen extends ConsumerStatefulWidget {
  const NativeTrendsScreen({super.key});

  @override
  ConsumerState<NativeTrendsScreen> createState() => _TrendsState();
}

class _TrendsState extends ConsumerState<NativeTrendsScreen> {
  int _range = 0;
  int _nutrient = 0;

  @override
  Widget build(BuildContext context) {
    final days = [7, 30, 90][_range];
    // 以共享本地日期为截止日构造连续窗口；跨日更新查询而不重置筛选。
    final end = ref.watch(currentDateProvider);
    final dates = List.generate(
      days,
      (i) => DateTime(end.year, end.month, end.day - days + i + 1),
    );
    final query = (
      dateFrom: formatIsoDate(dates.first),
      dateTo: formatIsoDate(end),
    );
    final result = ref.watch(dailyTrendProvider(query));
    final field = kCoreNutrientFields[_nutrient];
    final byDate = {
      for (final day in result.value?.days ?? <DailySummary>[])
        day.localDate: day,
    };
    final values = [
      for (final date in dates)
        recordedNutrient(byDate[formatIsoDate(date)], field.$1),
    ];
    // 均值分母只统计本营养素存在数值的记录日，显式零值同样计入。
    final known = values.whereType<double>().toList();
    final average = known.isEmpty
        ? null
        : known.reduce((a, b) => a + b) / known.length;

    return AppPage(
      demoLabel: null,
      title: '营养趋势',
      eyebrow: '${query.dateFrom} — ${query.dateTo}',
      children: [
        AppSegmented(
          labels: const ['7 日', '30 日', '90 日'],
          selected: _range,
          equalWidth: true,
          onChanged: (value) => setState(() => _range = value),
        ),
        AppSegmented(
          labels: kCoreNutrientFields.map((f) => f.$2).toList(),
          selected: _nutrient,
          equalWidth: true,
          onChanged: (value) => setState(() => _nutrient = value),
        ),
        if (result.isLoading && result.value == null)
          const Center(child: CircularProgressIndicator()),
        if (result.hasError)
          _TrendErrorCard(
            error: result.error!,
            onRetry: () =>
                ref.read(nutritionManagerProvider).refreshDailyTrend(query),
          ),
        if (result.value != null) ...[
          _NativeTrendChartCard(
            label: field.$2,
            unit: field.$3,
            average: average,
            knownCount: known.length,
            days: days,
            dates: dates,
            values: values,
            byDate: byDate,
          ),
          AppCard(
            child: Text(
              '日均分母仅含本营养素有数值的记录日（${known.length}/$days）。无记录不表示完整零摄入，不同营养素的分母可能不同。',
            ),
          ),
          const SectionHeading(title: '逐日记录概况'),
          _DailyTrendBreakdownCard(
            dates: dates,
            values: values,
            byDate: byDate,
            unit: field.$3,
          ),
        ],
      ],
    );
  }
}

class _TrendErrorCard extends StatelessWidget {
  const _TrendErrorCard({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: [
        Text('$error'),
        TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}

class _NativeTrendChartCard extends StatelessWidget {
  const _NativeTrendChartCard({
    required this.label,
    required this.unit,
    required this.average,
    required this.knownCount,
    required this.days,
    required this.dates,
    required this.values,
    required this.byDate,
  });

  final String label;
  final String unit;
  final double? average;
  final int knownCount;
  final int days;
  final List<DateTime> dates;
  final List<double?> values;
  final Map<String, DailySummary> byDate;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(title: '$label每日变化', detail: unit),
        Text('日均 ${_formatTrendAmount(average)} $unit · $knownCount 个有数值记录日'),
        const SizedBox(height: 18),
        NutritionBarChart(
          values: values,
          labels: dates.map((d) => '${d.month}/${d.day}').toList(),
          unit: unit,
          highlightLast: true,
          showValueLabels: days == 7,
          missingLabels: [
            for (final date in dates)
              (byDate[formatIsoDate(date)]?.mealCount ?? 0) == 0 ? '未记录' : '未知',
          ],
        ),
      ],
    ),
  );
}

class _DailyTrendBreakdownCard extends StatelessWidget {
  const _DailyTrendBreakdownCard({
    required this.dates,
    required this.values,
    required this.byDate,
    required this.unit,
  });

  final List<DateTime> dates;
  final List<double?> values;
  final Map<String, DailySummary> byDate;
  final String unit;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: [
        for (var i = 0; i < dates.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text(formatIsoDate(dates[i]))),
                Text('${byDate[formatIsoDate(dates[i])]?.mealCount ?? 0} 餐'),
                const SizedBox(width: 18),
                Flexible(child: Text('${_formatTrendAmount(values[i])} $unit')),
              ],
            ),
          ),
      ],
    ),
  );
}
