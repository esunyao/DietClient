import 'package:diet_models/diet_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_fixtures.dart';

// 重新导出样例和模型，其他文件导入本文件后也能使用这些类型与数据。
export 'demo_fixtures.dart';

export 'package:diet_models/diet_models.dart';

/// 某一时刻的演示内存状态快照，包含餐食、资料、配餐、报告与界面开关。
class DemoSnapshot {
  const DemoSnapshot({
    required this.meals,
    this.mode = ExperienceMode.personal,
    this.profile = const PersonProfile(),
    this.selectedPlanId = 'fish',
    this.planSaved = false,
    this.aiConsent = true,
    this.institutionConfirmed = false,
    this.restrictionChecked = false,
    this.privacyHidden = false,
    this.healthRecords = initialHealthRecords,
    // 初始报告是固定样例；stale 表示需要根据最新餐食重新生成。
    this.reports = const [
      ReportPreview(
        id: 'weekly-1',
        title: '本周营养记录报告',
        period: '9月26日 - 10月2日',
        average: 1547,
        version: 1,
      ),
      ReportPreview(
        id: 'september',
        title: '9月营养记录报告',
        period: '9月1日 - 9月30日',
        average: 1600,
        version: 1,
        stale: true,
      ),
    ],
  });

  /// 全部演示餐食列表（可能跨越多个日期）。
  final List<MealEntry> meals;

  /// 当前演示体验模式：个人或机构。
  final ExperienceMode mode;

  /// 演示中的个人基础资料。
  final PersonProfile profile;

  /// 已选择的配餐方案 ID。
  final String selectedPlanId;

  /// 当前配餐方案是否已在演示中保存。
  final bool planSaved;

  /// 演示中的 AI 同意开关（仅演示用途，不代表真实授权）。
  final bool aiConsent;

  /// 本轮演示中的机构餐是否已确认。
  final bool institutionConfirmed;

  /// 是否已完成机构餐确认前的限制核对。
  final bool restrictionChecked;

  /// 演示页面是否隐藏个人内容。
  final bool privacyHidden;

  /// 演示健康记录预览列表。
  final List<HealthRecordPreview> healthRecords;

  /// 演示报告预览列表。
  final List<ReportPreview> reports;

  /// 当前演示模式是否为机构模式。
  bool get isInstitution => mode == ExperienceMode.institution;

  /// 按 [selectedPlanId] 获取对应的完整配餐方案。
  PlanOption get selectedPlan =>
      demoPlans.firstWhere((p) => p.id == selectedPlanId);

  /// 获取演示当天（[demoDate]）的全部餐食，按食用时间升序排列。
  List<MealEntry> get todayMeals =>
      meals.where((m) => sameDay(m.consumedAt, demoDate)).toList()
        ..sort((a, b) => a.consumedAt.compareTo(b.consumedAt));

  /// 当天已确认且分析就绪的餐食营养合计。
  Nutrients get todayTotal => totalFor(todayMeals);

  /// 按餐食 ID 查找演示餐食；找不到时返回 `null`。
  MealEntry? meal(String id) {
    for (final entry in meals) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// 生成截至 [demoDate] 的连续 [days] 天营养趋势点（无餐食日保留空点）。
  List<TrendPoint> trend(int days) => List.generate(days, (i) {
    final date = demoDate.subtract(Duration(days: days - i - 1));
    final entries = meals.where((m) => sameDay(m.consumedAt, date)).toList();
    return TrendPoint(
      date: date,
      nutrients: totalFor(entries),
      // 总记录数包含该日所有状态；营养合计仅包含可参与统计的记录。
      recordCount: entries.length,
      analyzingCount: entries
          .where((e) => e.status == AnalysisStatus.analyzing)
          .length,
    );
  });

  /// 复制并替换传入的非 `null` 字段；列表字段以不可变列表包装，[mode] 由控制器单独切换。
  DemoSnapshot copyWith({
    List<MealEntry>? meals,
    PersonProfile? profile,
    String? selectedPlanId,
    bool? planSaved,
    bool? aiConsent,
    bool? institutionConfirmed,
    bool? restrictionChecked,
    bool? privacyHidden,
    List<HealthRecordPreview>? healthRecords,
    List<ReportPreview>? reports,
  }) => DemoSnapshot(
    // 创建不可修改的列表，避免调用方直接 add/remove 绕过状态更新入口。
    // 这是列表层面的保护，不会自动深拷贝或冻结每个元素。
    meals: List.unmodifiable(meals ?? this.meals),
    mode: mode,
    profile: profile ?? this.profile,
    selectedPlanId: selectedPlanId ?? this.selectedPlanId,
    planSaved: planSaved ?? this.planSaved,
    aiConsent: aiConsent ?? this.aiConsent,
    institutionConfirmed: institutionConfirmed ?? this.institutionConfirmed,
    restrictionChecked: restrictionChecked ?? this.restrictionChecked,
    privacyHidden: privacyHidden ?? this.privacyHidden,
    healthRecords: List.unmodifiable(healthRecords ?? this.healthRecords),
    reports: List.unmodifiable(reports ?? this.reports),
  );
}

/// 合计已确认且分析就绪的餐食营养值；某项全缺失时返回 `null` 表示未知而非零。
Nutrients totalFor(Iterable<MealEntry> entries) {
  final ready = entries
      .where((e) => e.confirmed && e.status == AnalysisStatus.ready)
      .toList();
  // 局部函数：根据营养编码提取数值，只保留非 null 的 double 再求和。
  double? sum(String code) {
    final values = ready
        .map((e) => e.nutrients.value(code))
        .whereType<double>()
        .toList();
    return values.isEmpty ? null : values.fold<double>(0, (a, b) => a + b);
  }

  return Nutrients(
    energy: sum('energy'),
    protein: sum('protein'),
    carbs: sum('carbs'),
    fat: sum('fat'),
    fiber: sum('fiber'),
    sodium: sum('sodium'),
  );
}

/// 内存演示状态控制器；所有状态更新仅保存在内存中。
class DemoController extends Notifier<DemoSnapshot> {
  @override
  DemoSnapshot build() => DemoSnapshot(meals: initialMeals());

  /// 切换演示体验模式并重置全部默认样例。
  void selectMode(ExperienceMode mode) =>
      state = DemoSnapshot(meals: initialMeals(), mode: mode);

  /// 更新演示个人基础资料。
  void updateProfile(PersonProfile profile) =>
      state = state.copyWith(profile: profile);

  /// 选择演示配餐方案并重置保存状态。
  void selectPlan(String id) {
    if (demoPlans.any((p) => p.id == id)) {
      state = state.copyWith(selectedPlanId: id, planSaved: false);
    }
  }

  /// 标记当前演示配餐方案为已保存。
  void savePlan() => state = state.copyWith(planSaved: true);

  /// 更新演示 AI 同意状态。
  void setAiConsent(bool value) => state = state.copyWith(aiConsent: value);

  /// 更新演示隐私遮罩开关。
  void setPrivacyHidden(bool value) =>
      state = state.copyWith(privacyHidden: value);

  /// 更新机构餐限制核对开关。
  void setRestrictionChecked(bool value) =>
      state = state.copyWith(restrictionChecked: value);

  /// 新增或替换演示餐食，并将既有报告标记为过期。
  void saveMeal(MealEntry meal) => state = state.copyWith(
    meals: [...state.meals.where((m) => m.id != meal.id), meal],
    reports: state.reports.map((r) => r.copyWith(stale: true)).toList(),
  );

  /// 移除指定演示餐食，并将既有报告标记为过期。
  void removeMeal(String id) => state = state.copyWith(
    meals: state.meals.where((m) => m.id != id).toList(),
    reports: state.reports.map((r) => r.copyWith(stale: true)).toList(),
  );

  /// 新增或替换一条演示健康记录预览。
  void saveHealthRecord(HealthRecordPreview entry) => state = state.copyWith(
    healthRecords: [
      ...state.healthRecords.where((r) => r.id != entry.id),
      entry,
    ],
  );

  /// 删除指定的演示健康记录预览。
  void removeHealthRecord(String id) => state = state.copyWith(
    healthRecords: state.healthRecords.where((r) => r.id != id).toList(),
  );

  /// 确认机构演示餐并按食用比例 [fraction]（`(0, 1]`）写入演示餐食。
  void confirmInstitutionMeal({required double fraction}) {
    if (!state.restrictionChecked ||
        state.institutionConfirmed ||
        fraction <= 0 ||
        fraction > 1) {
      return;
    }
    final meal = MealEntry(
      id: 'institution-dinner',
      title: '清蒸鱼套餐',
      type: MealType.dinner,
      consumedAt: DateTime(2026, 10, 2, 18),
      nutrients: Nutrients(energy: 520 * fraction, protein: 38 * fraction),
      source: RecordSource.institution,
      notes: '本人归属与实际食用量已在演示中核对',
    );
    saveMeal(meal);
    state = state.copyWith(institutionConfirmed: true);
  }

  /// 基于演示日期最近七天的已知能量均值生成一条演示报告预览。
  void generateReport() {
    final values = state
        .trend(7)
        .map((p) => p.nutrients.energy)
        .whereType<double>()
        .toList();
    final average = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a + b) / values.length;
    final version =
        state.reports.where((r) => r.id.startsWith('weekly')).length + 1;
    state = state.copyWith(
      reports: [
        ReportPreview(
          id: 'weekly-$version',
          title: '本周营养记录报告',
          period: '9月26日 - 10月2日',
          average: average.roundToDouble(),
          version: version,
        ),
        ...state.reports,
      ],
    );
  }

  /// 恢复默认演示样例，同时保留当前选择的个人或机构模式。
  void reset() => state = DemoSnapshot(meals: initialMeals(), mode: state.mode);
}

/// 全局演示内存状态 Provider。
final demoProvider = NotifierProvider<DemoController, DemoSnapshot>(
  DemoController.new,
);
