import 'package:flutter/material.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/demo/demo_store.dart';

String mealDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String mealTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class MealRow extends StatelessWidget {
  const MealRow({super.key, required this.meal, required this.onTap});
  final MealEntry meal;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AppCard(
    child: InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PlateIllustration(size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      meal.type.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      mealTime(meal.consumedAt),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(meal.title),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      meal.status == AnalysisStatus.ready
                          ? '${formatAmount(meal.nutrients.energy)}${meal.nutrients.energy == null ? '' : ' kcal'}'
                          : '待分析',
                    ),
                    AppBadge(label: meal.status.label),
                    Text(
                      meal.source.label,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (!meal.confirmed)
                  const Text(
                    '待确认，尚未计入摄入',
                    style: TextStyle(color: AppColors.amberInk),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
        ],
      ),
    ),
  );
}

class MealNutrients extends StatelessWidget {
  const MealNutrients({super.key, required this.nutrients});
  final Nutrients nutrients;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final width = c.maxWidth < 330 ? c.maxWidth : (c.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children:
            [
                  ('能量', nutrients.energy, 'kcal'),
                  ('蛋白质', nutrients.protein, 'g'),
                  ('碳水', nutrients.carbs, 'g'),
                  ('脂肪', nutrients.fat, 'g'),
                ]
                .map(
                  (v) => SizedBox(
                    width: width,
                    child: MetricTile(
                      label: v.$1,
                      value: formatAmount(v.$2),
                      unit: v.$2 == null ? null : v.$3,
                    ),
                  ),
                )
                .toList(),
      );
    },
  );
}
