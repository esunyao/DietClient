import '../../../core/nutrition/data/nutri_models.dart';

/// Per-item values keep the original server codes, including unfamiliar metrics.
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
