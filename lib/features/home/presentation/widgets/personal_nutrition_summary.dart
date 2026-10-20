import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';

import '../../../../demo/demo_nutrition_targets.dart';
import '../../../../demo/demo_store.dart';
import 'home_summary.dart';

class PersonalNutritionSummary extends StatelessWidget {
  const PersonalNutritionSummary({super.key, required this.data});
  final DemoSnapshot data;
  @override
  Widget build(BuildContext context) {
    final total = data.todayTotal;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '今日营养',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const Text('演示目标', style: AppTypography.small),
              Text(
                total.energy == null
                    ? '剩余未知'
                    : total.energy! <= DemoNutritionTargets.energy
                    ? '还剩 ${homeAmount(DemoNutritionTargets.energy - total.energy!)} kcal'
                    : '超出 ${homeAmount(total.energy! - DemoNutritionTargets.energy)} kcal',
                style: AppTypography.small,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 6,
            children: [
              Text(
                homeAmount(total.energy),
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '/ ${homeAmount(DemoNutritionTargets.energy)} kcal',
                style: const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Progress(
            value: total.energy,
            target: DemoNutritionTargets.energy,
            color: AppColors.primary,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final vertical =
                  MediaQuery.textScalerOf(context).scale(14) > 22 ||
                  constraints.maxWidth < 260;
              final nutrients = [
                _Macro(
                  label: '蛋白质',
                  value: total.protein,
                  target: DemoNutritionTargets.protein,
                  color: const Color(0xFF54BE94),
                ),
                _Macro(
                  label: '碳水化合物',
                  value: total.carbs,
                  target: DemoNutritionTargets.carbs,
                  color: const Color(0xFFF5B72B),
                ),
                _Macro(
                  label: '脂肪',
                  value: total.fat,
                  target: DemoNutritionTargets.fat,
                  color: const Color(0xFFFF777D),
                ),
              ];
              if (vertical) {
                return Column(
                  children: [
                    for (final nutrient in nutrients)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: nutrient,
                      ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < nutrients.length; i++) ...[
                    if (i > 0) const SizedBox(width: 14),
                    Expanded(child: nutrients[i]),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          const Text('演示目标仅供展示 · 已确认记录非全天摄入', style: AppTypography.small),
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({
    required this.label,
    required this.value,
    required this.target,
    required this.color,
  });
  final String label;
  final double? value;
  final double target;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTypography.body),
      const SizedBox(height: 4),
      Text(
        '${homeAmount(value)} / ${homeAmount(target)} g',
        style: AppTypography.caption,
      ),
      const SizedBox(height: 8),
      _Progress(value: value, target: target, color: color),
    ],
  );
}

class _Progress extends StatelessWidget {
  const _Progress({
    required this.value,
    required this.target,
    required this.color,
  });
  final double? value;
  final double target;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Semantics(
          label: value == null ? '进度未知' : '${(value! / target * 100).round()}%',
          child: ExcludeSemantics(
            child: LinearProgressIndicator(
              value: value == null ? 0 : (value! / target).clamp(0, 1),
              minHeight: 7,
              borderRadius: BorderRadius.circular(8),
              color: color,
              backgroundColor: AppColors.line,
            ),
          ),
        ),
      ),
      const SizedBox(width: 7),
      Text(
        value == null ? '未知' : '${(value! / target * 100).round()}%',
        style: AppTypography.caption,
      ),
    ],
  );
}
