import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';

import '../../../../core/nutrition/application/nutrition_providers.dart';
import '../../../../core/presentation/ui_preferences.dart';
import 'meal_photo_widgets.dart';

String nutritionDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
const mealTypes = {
  'breakfast': '早餐',
  'lunch': '午餐',
  'dinner': '晚餐',
  'snack': '加餐',
  'other': '其他',
};
String statusLabel(String status) => switch (status) {
  'queued' || 'pending' => '等待分析',
  'analysing' || 'analyzing' => '分析中',
  'completed' => '已分析',
  'failed' => '分析失败',
  'needs_review' => '需要核对',
  _ => status,
};
String amountText(double? amount) => amount == null
    ? '未知'
    : amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);

class NativeNutrients extends StatelessWidget {
  const NativeNutrients({super.key, required this.values});
  final List<NutrientValue> values;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 20,
    runSpacing: 12,
    children: [
      for (final field in const [
        ('ENERGY_KCAL', '能量', 'kcal'),
        ('PROTEIN', '蛋白质', 'g'),
        ('CARBOHYDRATE', '碳水', 'g'),
        ('FAT', '脂肪', 'g'),
      ])
        Text(
          '${field.$2} ${amountText(nutrientAmount(values, field.$1))} ${field.$3}',
        ),
      for (final value in values.where(
        (n) => !const [
          'ENERGY_KCAL',
          'PROTEIN',
          'CARBOHYDRATE',
          'FAT',
        ].contains(n.nutrientCode),
      ))
        Text('${value.nutrientName} ${amountText(value.amount)} ${value.unit}'),
    ],
  );
}

class NativeMealTile extends StatelessWidget {
  const NativeMealTile({
    super.key,
    required this.meal,
    required this.onTap,
    required this.onPhotoTap,
    this.layout = MealHistoryLayout.compact,
  });
  final MealHistoryItem meal;
  final VoidCallback onTap;
  final ValueChanged<String> onPhotoTap;
  final MealHistoryLayout layout;
  @override
  Widget build(BuildContext context) {
    final details = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${meal.localDate} · ${mealTypes[meal.mealType] ?? meal.mealType}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            Text(
              '${meal.consumedAt.toLocal().hour.toString().padLeft(2, '0')}:${meal.consumedAt.toLocal().minute.toString().padLeft(2, '0')} · ${statusLabel(meal.analysisStatus)}',
              style: AppTypography.small,
            ),
            Text(
              '${amountText(nutrientAmount(meal.nutrients, 'ENERGY_KCAL'))} kcal',
            ),
            if (meal.notes?.isNotEmpty ?? false)
              Text(meal.notes!, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
    final photo = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: MealPhotoCover(
        mealId: meal.mealId,
        onOpen: onPhotoTap,
        decodeWidth: layout == MealHistoryLayout.compact ? 288 : 1080,
      ),
    );
    return AppCard(
      child: layout == MealHistoryLayout.photoCard
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(aspectRatio: 16 / 9, child: photo),
                const SizedBox(height: 12),
                details,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(dimension: 96, child: photo),
                const SizedBox(width: 14),
                Expanded(child: details),
              ],
            ),
    );
  }
}

class NutritionError extends StatelessWidget {
  const NutritionError({super.key, required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: [
        Text('$error'),
        TextButton(onPressed: retry, child: const Text('重试')),
      ],
    ),
  );
}
