import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class NutritionBarChart extends StatelessWidget {
  const NutritionBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.color,
    this.unit = 'kcal',
  });
  final List<double?> values;
  final List<String> labels;
  final Color? color;
  final String unit;
  @override
  Widget build(BuildContext context) => Semantics(
    label: List.generate(
      values.length,
      (i) =>
          '${i < labels.length ? labels[i] : i + 1}：${values[i] == null ? '未记录' : '${values[i]} $unit'}',
    ).join('，'),
    child: SizedBox(
      height: 210,
      child: BarChart(
        BarChartData(
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: values[i] == null
                    ? []
                    : [
                        BarChartRodData(
                          toY: values[i]!,
                          color: color ?? AppColors.primary,
                          width: values.length > 30
                              ? 3
                              : values.length > 7
                              ? 7
                              : 18,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ],
              ),
          ],
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 44),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 ||
                      i >= labels.length ||
                      (labels.length > 10 &&
                          i % (labels.length ~/ 7) != 0 &&
                          i != labels.length - 1)) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      labels[i],
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(
                    '${rod.toY.toStringAsFixed(0)} $unit',
                    const TextStyle(color: Colors.white),
                  ),
            ),
          ),
        ),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
      ),
    ),
  );
}
