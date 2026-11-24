import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';

import '../../../../core/nutrition/application/nutrition_providers.dart';
import '../../../../core/presentation/ui_preferences.dart';
import 'meal_photo_widgets.dart';

/// 真实餐食营养素展示组，缺失的核心指标显示“未知”，额外指标保留原名称与单位。
class NativeNutrients extends StatelessWidget {
  const NativeNutrients({super.key, required this.values});

  final List<NutrientValue> values;

  @override
  Widget build(BuildContext context) {
    const coreCodes = {'ENERGY_KCAL', 'PROTEIN', 'CARBOHYDRATE', 'FAT'};
    return Wrap(
      spacing: 20,
      runSpacing: 12,
      children: [
        for (final field in kCoreNutrientFields)
          Text(
            '${field.$2} ${formatNutrientAmount(nutrientAmount(values, field.$1))} ${field.$3}',
          ),
        for (final value in values.where(
          (n) => !coreCodes.contains(n.nutrientCode),
        ))
          Text(
            '${value.nutrientName} ${formatNutrientAmount(value.amount)} ${value.unit}',
          ),
      ],
    );
  }
}

/// 真实历史餐食列表项组件，按外观偏好渲染紧凑行或照片卡片视图。
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
              '${meal.localDate} · ${mealTypeLabel(meal.mealType)}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            Text(
              '${formatLocalTime(meal.consumedAt)} · ${analysisStatusLabel(meal.analysisStatus)}',
              style: AppTypography.small,
            ),
            Text(
              '${formatNutrientAmount(nutrientAmount(meal.nutrients, 'ENERGY_KCAL'))} kcal',
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

/// 营养查询失败提示卡片，将重试操作交还给调用方。
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
