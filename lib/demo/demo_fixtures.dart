import 'package:diet_models/diet_models.dart';

final demoDate = DateTime(2026, 10, 2);

const demoPlans = [
  PlanOption(id: 'fish', name: '清蒸鱼套餐', energy: 520, protein: 38, minutes: 25, reason: '主食、优质蛋白与蔬菜组合，参考已记录的摄入安排。', foods: [FoodPortion(id: 'fish', name: '清蒸鲈鱼', grams: 150), FoodPortion(id: 'rice', name: '糙米饭', grams: 120), FoodPortion(id: 'broccoli', name: '焯拌西兰花', grams: 180)]),
  PlanOption(id: 'tofu', name: '豆腐蔬菜碗', energy: 480, protein: 26, minutes: 20, reason: '植物蛋白搭配杂粮和时蔬，菜品与供应信息仍需核对。', foods: [FoodPortion(id: 'tofu', name: '嫩豆腐', grams: 180), FoodPortion(id: 'rice', name: '杂粮饭', grams: 100), FoodPortion(id: 'greens', name: '清炒时蔬', grams: 200)]),
  PlanOption(id: 'chicken', name: '鸡肉杂粮饭', energy: 560, protein: 42, minutes: 15, reason: '适合时间较少的一餐；计划营养不计入已吃的记录。', foods: [FoodPortion(id: 'chicken', name: '香煎鸡胸肉', grams: 150), FoodPortion(id: 'rice', name: '杂粮饭', grams: 150), FoodPortion(id: 'greens', name: '拌蔬菜', grams: 180)]),
];

List<MealEntry> initialMeals() {
  final meals = <MealEntry>[];
  const totals = {26: 1550.0, 27: 1680.0, 29: 1740.0, 30: 1630.0};
  for (final day in totals.keys) {
    for (var i = 0; i < 3; i++) {
      final value = i == 0 ? 400.0 : i == 1 ? 650.0 : totals[day]! - 1050;
      meals.add(MealEntry(id: 'sep-$day-$i', title: ['全麦吐司、鸡蛋、牛奶', '杂粮饭、鱼、蔬菜', '豆腐、菌菇、青菜'][i], type: MealType.values[i], consumedAt: DateTime(2026, 9, day, [8, 12, 18][i], 10), nutrients: Nutrients(energy: value)));
    }
  }
  for (var i = 0; i < 3; i++) {
    meals.add(MealEntry(id: 'oct-1-$i', title: ['全麦三明治', '鸡肉蔬菜饭', '豆腐、杂粮饭、青菜'][i], type: MealType.values[i], consumedAt: DateTime(2026, 10, 1, [8, 12, 18][i], 40), nutrients: Nutrients(energy: [400.0, 650.0, 530.0][i]), source: RecordSource.manual));
  }
  meals.addAll([
    MealEntry(id: 'breakfast', title: '全麦吐司、鸡蛋、牛奶', type: MealType.breakfast, consumedAt: DateTime(2026, 10, 2, 8, 10), nutrients: const Nutrients(energy: 420, protein: 22, carbs: 45, fat: 16)),
    MealEntry(id: 'lunch', title: '糙米饭、煎鱼、清炒西兰花', type: MealType.lunch, consumedAt: DateTime(2026, 10, 2, 12, 25), nutrients: const Nutrients(energy: 680, protein: 30, carbs: 87, fat: 24), foods: const [FoodPortion(id: 'rice', name: '糙米饭', grams: 200, nutrients: Nutrients(energy: 260)), FoodPortion(id: 'fish', name: '煎鱼', grams: 150, nutrients: Nutrients(energy: 300)), FoodPortion(id: 'broccoli', name: '清炒西兰花', grams: 150, nutrients: Nutrients(energy: 120))]),
    MealEntry(id: 'snack', title: '已提交，稍后更新营养结果', type: MealType.snack, consumedAt: DateTime(2026, 10, 2, 15, 30), nutrients: const Nutrients(), status: AnalysisStatus.analyzing),
  ]);
  return meals;
}

const initialHealthRecords = [
  HealthRecordPreview(id: 'weight', kind: 'measurement', title: '体重', value: '58.4 kg', note: '手工记录，可查看历史测量'),
  HealthRecordPreview(id: 'goal', kind: 'goal', title: '健康目标', value: '维持体重', note: '进行中，营养目标需确认来源'),
  HealthRecordPreview(id: 'allergy', kind: 'allergy', title: '花生', value: '已登记', note: '严重程度待确认；推荐需避开'),
];
