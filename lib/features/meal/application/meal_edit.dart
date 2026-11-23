import '../../../core/nutrition/data/nutri_models.dart';

/// @brief Editable draft model for a single meal item during correction.
/// @details Per-item values keep the original server codes, including unfamiliar metrics.
class MealItemEdit {
  MealItemEdit({this.original})
    : name = original?.displayName ?? '',
      weight = original?.estimatedWeightG?.toString() ?? '',
      notes = original?.notes ?? '',
      amounts = {
        for (final n in original?.nutrients ?? <NutrientValue>[])
          n.nutrientCode: n.amount.toString(),
      };
  final MealItem? original;
  String name, weight, notes;
  final Map<String, String> amounts;

  /// @brief 校验当前菜品草稿并转换为修正提交载荷。
  /// @details 重量可留空，空营养输入不提交；每道菜至少需一项有效营养值，保留原菜品 ID，修改重量不会自动推算营养。
  /// @return 校验通过的 MealCorrectionItem 对象。
  /// @throws FormatException 当菜品名称、备注、重量或营养输入不符合约束时抛出。
  MealCorrectionItem toInput() {
    if (name.trim().isEmpty || name.trim().length > 150) {
      throw const FormatException('菜品名称需为 1–150 字');
    }
    if (notes.length > 500) throw const FormatException('菜品备注不能超过 500 字');
    final grams = weight.trim().isEmpty ? null : double.tryParse(weight);
    if (weight.trim().isNotEmpty &&
        (grams == null || !grams.isFinite || grams < .001 || grams > 100000)) {
      throw const FormatException('重量需在 0.001–100000 g 之间，未知可留空');
    }
    final nutrients = <MealNutrientInput>[];
    for (final entry in amounts.entries) {
      if (entry.value.trim().isEmpty) continue;
      final value = double.tryParse(entry.value);
      if (value == null || !value.isFinite || value < 0) {
        throw const FormatException('营养值需为有效非负数');
      }
      nutrients.add(MealNutrientInput(nutrientCode: entry.key, amount: value));
    }
    if (nutrients.isEmpty || nutrients.length > 100) {
      throw const FormatException('每道菜至少填写一条营养值，最多 100 条');
    }
    return MealCorrectionItem(
      itemId: original?.itemId,
      displayName: name.trim(),
      estimatedWeightG: grams,
      notes: notes.trim().isEmpty ? null : notes.trim(),
      nutrients: nutrients,
    );
  }
}
