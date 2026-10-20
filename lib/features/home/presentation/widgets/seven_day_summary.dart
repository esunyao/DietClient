import 'dart:math' as math;

import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/app_routes.dart';
import '../../../../demo/demo_store.dart';
import 'home_summary.dart';

class SevenDaySummary extends StatelessWidget {
  const SevenDaySummary({super.key, required this.points});
  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final known = points
        .map((point) => point.nutrients.energy)
        .whereType<double>()
        .toList();
    final average = known.isEmpty
        ? null
        : (known.reduce((a, b) => a + b) / known.length).roundToDouble();
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '近7日记录',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '${known.length}个有数值记录日',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            height: 1.2,
          ),
        ),
      ],
    );
    final value = Text.rich(
      TextSpan(
        text: homeAmount(average),
        children: const [
          TextSpan(
            text: ' kcal / 记录日均',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      style: const TextStyle(
        fontSize: 27,
        fontWeight: FontWeight.w700,
        height: 1.2,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
    return AppCard(
      radius: 16,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.trends),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 650 ||
                  MediaQuery.textScalerOf(context).scale(14) > 18;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    const SizedBox(height: 12),
                    value,
                    const SizedBox(height: 16),
                    SizedBox(height: 49, child: _EnergyBars(points: points)),
                  ],
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 57),
                child: Row(
                  children: [
                    SizedBox(width: 167, child: heading),
                    const SizedBox(width: 20),
                    Expanded(child: value),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 218,
                      height: 49,
                      child: _EnergyBars(points: points),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EnergyBars extends StatelessWidget {
  const _EnergyBars({required this.points});
  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final known = points
        .map((point) => point.nutrients.energy)
        .whereType<double>();
    final maximum = known.fold<double>(1800, math.max);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final point in points)
          Expanded(
            child: Tooltip(
              message:
                  '${point.date.month}月${point.date.day}日：${point.nutrients.energy == null ? '无已知营养值' : '${homeAmount(point.nutrients.energy)} kcal'}',
              child: Semantics(
                label: '${point.date.month}月${point.date.day}日已记录能量',
                value: point.nutrients.energy == null
                    ? '无已知数值，不补零'
                    : '${homeAmount(point.nutrients.energy)} 千卡',
                child: SizedBox.expand(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: point.nutrients.energy == null
                        ? const Padding(
                            padding: EdgeInsets.only(bottom: 5),
                            child: SizedBox(
                              width: 12,
                              height: 12,
                              child: CustomPaint(painter: _MissingDayPainter()),
                            ),
                          )
                        : Container(
                            width: 18,
                            height:
                                49.0 *
                                (point.nutrients.energy! / maximum).clamp(0, 1),
                            decoration: BoxDecoration(
                              color: sameDay(point.date, demoDate)
                                  ? AppColors.primary
                                  : const Color(0xFF8FAF9A),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MissingDayPainter extends CustomPainter {
  const _MissingDayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(3),
    );
    canvas.drawRRect(shape, Paint()..color = AppColors.surfaceMuted);
    canvas.save();
    canvas.clipRRect(shape);
    final paint = Paint()
      ..color = const Color(0xFFB7CABC)
      ..strokeWidth = 1;
    for (var x = -size.height; x <= size.width; x += 5) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MissingDayPainter oldDelegate) => false;
}
