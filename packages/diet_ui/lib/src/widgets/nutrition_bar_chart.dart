import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class NutritionBarChart extends StatelessWidget {
  const NutritionBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.color,
    this.unit = 'kcal',
    this.height = 210,
    this.highlightLast = false,
    this.showValueLabels = false,
    this.missingLabels,
  }) : assert(missingLabels == null || missingLabels.length == values.length);
  final List<double?> values;
  final List<String> labels;
  final Color? color;
  final String unit;
  final double height;
  final bool highlightLast;
  final bool showValueLabels;
  final List<String>? missingLabels;

  String _missing(int index) => missingLabels?[index] ?? '未记录';
  String _number(double value) =>
      value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scaler = MediaQuery.textScalerOf(context);
      final extraTextHeight = math.max(0.0, scaler.scale(11) - 11);
      var maxLabelWidth = 0.0;
      for (final value in values.whereType<double>()) {
        final painter = TextPainter(
          text: TextSpan(
            text: _number(value),
            style: AppTypography.small.copyWith(fontSize: 11),
          ),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout();
        maxLabelWidth = math.max(maxLabelWidth, painter.width);
        painter.dispose();
      }
      final inlineLabels =
          showValueLabels &&
          values.isNotEmpty &&
          values.length <= 10 &&
          maxLabelWidth + 8 <= (constraints.maxWidth - 44) / values.length;
      final knownMax = values.whereType<double>().fold<double>(0, math.max);
      final showMissing = missingLabels != null || highlightLast;
      return Semantics(
        label: List.generate(
          values.length,
          (i) =>
              '${i < labels.length ? labels[i] : i + 1}：${values[i] == null ? _missing(i) : '${_number(values[i]!)} $unit'}',
        ).join('，'),
        child: SizedBox(
          height: height + extraTextHeight * 3,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: inlineLabels && knownMax > 0 ? knownMax * 1.2 : null,
              barGroups: [
                for (var i = 0; i < values.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: values[i] == null
                        ? []
                        : [
                            BarChartRodData(
                              toY: values[i]!,
                              color: highlightLast && i != values.length - 1
                                  ? AppColors.greenSoft
                                  : color ?? AppColors.primary,
                              width: values.length > 30
                                  ? 3
                                  : values.length > 7
                                  ? 7
                                  : 18,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                              label: BarChartRodLabel(
                                show: inlineLabels,
                                text: _number(values[i]!),
                                style: AppTypography.small.copyWith(
                                  fontSize: 11,
                                ),
                                offset: const Offset(0, 6),
                              ),
                            ),
                          ],
                  ),
              ],
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppColors.line,
                  strokeWidth: 1,
                  dashArray: [],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44 + extraTextHeight * 2,
                    getTitlesWidget: (value, meta) => Text(
                      meta.formattedValue,
                      style: AppTypography.small.copyWith(fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: (showMissing ? 52 : 32) + extraTextHeight * 3,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 ||
                          i >= labels.length ||
                          (labels.length > 10 &&
                              i % (labels.length ~/ 7) != 0 &&
                              i != labels.length - 1)) {
                        return const SizedBox.shrink();
                      }
                      final missing = i < values.length && values[i] == null;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              labels[i],
                              style: AppTypography.small.copyWith(fontSize: 10),
                            ),
                            if (showMissing && missing) ...[
                              const SizedBox(height: 3),
                              const CustomPaint(
                                size: Size(18, 8),
                                painter: _MissingMarkPainter(),
                              ),
                              Text(
                                _missing(i),
                                style: AppTypography.small.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchExtraThreshold: const EdgeInsets.all(12),
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                      BarTooltipItem(
                        '${group.x < labels.length ? '${labels[group.x]}\n' : ''}${_number(rod.toY)} $unit',
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
    },
  );
}

/// 缺失用独立纹理标识，不画成零值或有营养的柱形。
class _MissingMarkPainter extends CustomPainter {
  const _MissingMarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.surfaceMuted,
    );
    final paint = Paint()
      ..color = AppColors.muted.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 5) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MissingMarkPainter oldDelegate) => false;
}
