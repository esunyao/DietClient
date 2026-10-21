import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diet_ui/diet_ui.dart';

import '../../../../core/nutrition/application/nutrition_providers.dart';

String _date(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _amount(double? v) => v == null ? '未知' : v.toStringAsFixed(1);

/// Empty calendar dates and days without meals stay unknown, even if the server emits zero totals.
double? recordedNutrient(DailySummary? day, String code) =>
    day == null || day.mealCount == 0
    ? null
    : nutrientAmount(day.nutrients, code);

class NativeTrendsScreen extends ConsumerStatefulWidget {
  const NativeTrendsScreen({super.key});
  @override
  ConsumerState<NativeTrendsScreen> createState() => _TrendsState();
}

class _TrendsState extends ConsumerState<NativeTrendsScreen> {
  int _range = 0, _nutrient = 0;
  static const _fields = [
    ('ENERGY_KCAL', '能量', 'kcal'),
    ('PROTEIN', '蛋白质', 'g'),
    ('CARBOHYDRATE', '碳水', 'g'),
    ('FAT', '脂肪', 'g'),
  ];
  @override
  Widget build(BuildContext context) {
    final days = [7, 30, 90][_range];
    final end = DateUtils.dateOnly(DateTime.now());
    final dates = List.generate(
      days,
      (i) => DateTime(end.year, end.month, end.day - days + i + 1),
    );
    final query = (dateFrom: _date(dates.first), dateTo: _date(end));
    final result = ref.watch(dailyTrendProvider(query));
    final field = _fields[_nutrient];
    final byDate = {
      for (final day in result.value?.days ?? <DailySummary>[])
        day.localDate: day,
    };
    final values = [
      for (final date in dates) recordedNutrient(byDate[_date(date)], field.$1),
    ];
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
          onChanged: (v) => setState(() => _range = v),
        ),
        AppSegmented(
          labels: _fields.map((f) => f.$2).toList(),
          selected: _nutrient,
          equalWidth: true,
          onChanged: (v) => setState(() => _nutrient = v),
        ),
        if (result.isLoading && result.value == null)
          const Center(child: CircularProgressIndicator()),
        if (result.hasError)
          AppCard(
            child: Column(
              children: [
                Text('${result.error}'),
                TextButton(
                  onPressed: () => ref.invalidate(dailyTrendProvider(query)),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        if (result.value != null) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeading(title: '${field.$2}每日变化', detail: field.$3),
                Text(
                  '日均 ${_amount(average)} ${field.$3} · ${known.length} 个有数值记录日',
                ),
                const SizedBox(height: 18),
                NutritionBarChart(
                  values: values,
                  labels: dates.map((d) => '${d.month}/${d.day}').toList(),
                  unit: field.$3,
                  highlightLast: true,
                  showValueLabels: days == 7,
                  missingLabels: [
                    for (final date in dates)
                      (byDate[_date(date)]?.mealCount ?? 0) == 0 ? '未记录' : '未知',
                  ],
                ),
              ],
            ),
          ),
          AppCard(
            child: Text(
              '日均分母仅含本营养素有数值的记录日（${known.length}/$days）。无记录不表示完整零摄入，不同营养素的分母可能不同。',
            ),
          ),
          const SectionHeading(title: '逐日记录概况'),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < dates.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(_date(dates[i]))),
                        Text('${byDate[_date(dates[i])]?.mealCount ?? 0} 餐'),
                        const SizedBox(width: 18),
                        Flexible(
                          child: Text('${_amount(values[i])} ${field.$3}'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
