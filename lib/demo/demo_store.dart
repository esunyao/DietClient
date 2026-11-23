import 'package:diet_models/diet_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_fixtures.dart';

// 重新导出样例和模型，其他文件导入本文件后也能使用这些类型与数据。
export 'demo_fixtures.dart';

export 'package:diet_models/diet_models.dart';

/// @brief 某一时刻的演示状态集合，包含餐食、资料、配餐、报告和界面开关。
/// @details DemoController 用 state 持有当前快照；修改时创建新快照再赋给 state，让监听 demoProvider 的界面收到更新。
/// @note 数据只在内存中用于演示。
class DemoSnapshot {
  /// @brief 构造演示状态快照。
  /// @details meals 必须由调用方提供，其余参数省略时使用下方默认演示值。
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

  // final 表示字段初始化后不能重新赋值；它本身不会冻结 List 中的内容。
  /// @brief 全部演示餐食列表，可能跨越多个日期。
  final List<MealEntry> meals;

  /// @brief 当前演示体验模式：个人或机构。
  final ExperienceMode mode;

  /// @brief 演示中的个人基础资料。
  final PersonProfile profile;

  /// @brief 已选择的配餐方案 ID，用于从 demoPlans 查找完整方案。
  final String selectedPlanId;

  /// @brief 当前配餐方案是否已在演示中保存。
  final bool planSaved;

  /// @brief 演示中的 AI 同意开关。
  /// @note 不代表服务器上的真实授权记录。
  final bool aiConsent;

  /// @brief 本轮演示中的机构餐是否已经确认，用于防止重复加入。
  final bool institutionConfirmed;

  /// @brief 是否已完成机构餐确认前要求的限制核对。
  final bool restrictionChecked;

  /// @brief 演示页面是否隐藏个人内容。
  final bool privacyHidden;

  /// @brief 演示健康记录的预览列表。
  final List<HealthRecordPreview> healthRecords;

  /// @brief 演示报告的预览列表。
  final List<ReportPreview> reports;

  /// @brief 判断当前演示模式是否为机构模式。
  /// @return 当前模式为机构模式时返回 true，否则返回 false。
  bool get isInstitution => mode == ExperienceMode.institution;

  /// @brief 按已选方案 ID 获取完整配餐方案。
  /// @return 匹配的 PlanOption 对象。
  /// @throws StateError 当 demoPlans 中不存在匹配 ID 时由 firstWhere 抛出。
  PlanOption get selectedPlan =>
      demoPlans.firstWhere((p) => p.id == selectedPlanId);

  /// @brief 获取演示当天（demoDate）的全部餐食，按食用时间升序排列。
  /// @details “今天”以固定的 demoDate 为准，筛选后创建新列表并按食用时间从早到晚排序。
  /// @return 排序后的演示当天餐食列表。
  List<MealEntry> get todayMeals =>
      meals.where((m) => sameDay(m.consumedAt, demoDate)).toList()
        ..sort((a, b) => a.consumedAt.compareTo(b.consumedAt));

  /// @brief 当天已确认且分析就绪的餐食营养合计。
  /// @return 汇总后的 Nutrients 对象。
  Nutrients get todayTotal => totalFor(todayMeals);

  /// @brief 按餐食 ID 查找演示餐食。
  /// @param id 目标餐食 ID。
  /// @return 找到的 MealEntry；找不到时返回 null。
  MealEntry? meal(String id) {
    for (final entry in meals) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// @brief 生成截至 demoDate 的连续多日营养趋势。
  /// @details 顺序为最早一天到当天；没有餐食的日期也保留一个点，营养值由 totalFor 表达为未知。
  /// @param days 趋势涵盖的连续天数。
  /// @return 按日期升序排列的趋势数据点列表。
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

  /// @brief 基于当前快照创建新快照，仅替换传入的非 null 字段。
  /// @details 省略的字段保留原值；列表字段包装为不可修改列表；mode 保持原值，切换模式由 DemoController.selectMode 单独处理。
  /// @param meals 可选新餐食列表。
  /// @param profile 可选新个人基础资料。
  /// @param selectedPlanId 可选新配餐方案 ID。
  /// @param planSaved 可选配餐保存状态。
  /// @param aiConsent 可选 AI 同意状态。
  /// @param institutionConfirmed 可选机构餐确认状态。
  /// @param restrictionChecked 可选限制核对状态。
  /// @param privacyHidden 可选隐私隐藏状态。
  /// @param healthRecords 可选新健康记录预览列表。
  /// @param reports 可选新报告预览列表。
  /// @return 新创建的 DemoSnapshot 实例。
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

/// @brief 合计已确认且分析就绪的餐食营养值。
/// @details 每项营养分别忽略缺失值；某项完全没有已知数值时返回 null，表示未知而非摄入量为零。
/// @param entries 待参与汇总的餐食条目集合。
/// @return 汇总后的 Nutrients 对象。
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

/// @brief 演示状态控制器，管理 DemoSnapshot 内存状态。
/// @details 页面通过 ref.watch(demoProvider) 监听快照，通过 ref.read(demoProvider.notifier) 调用状态更新方法；方法以替换新快照的方式通知监听者重建。
class DemoController extends Notifier<DemoSnapshot> {
  /// @brief 构建并返回初始演示状态快照。
  /// @return 包含默认样例餐食的 DemoSnapshot。
  @override
  DemoSnapshot build() => DemoSnapshot(meals: initialMeals());

  /// @brief 切换演示体验模式并重置全部默认样例。
  /// @param mode 目标体验模式。
  void selectMode(ExperienceMode mode) =>
      state = DemoSnapshot(meals: initialMeals(), mode: mode);

  /// @brief 更新演示中的个人基础资料。
  /// @param profile 新的基础资料快照。
  void updateProfile(PersonProfile profile) =>
      state = state.copyWith(profile: profile);

  /// @brief 选择演示配餐方案。
  /// @details 只接受 demoPlans 中存在的方案；切换后将 planSaved 重置为 false。
  /// @param id 目标配餐方案 ID。
  void selectPlan(String id) {
    if (demoPlans.any((p) => p.id == id)) {
      state = state.copyWith(selectedPlanId: id, planSaved: false);
    }
  }

  /// @brief 标记当前演示配餐方案为已保存。
  /// @note 本方法及下方标记更新方法仅修改内存中的演示状态，不执行服务器请求或本地持久化。
  void savePlan() => state = state.copyWith(planSaved: true);
  void setAiConsent(bool value) => state = state.copyWith(aiConsent: value);
  void setPrivacyHidden(bool value) =>
      state = state.copyWith(privacyHidden: value);
  void setRestrictionChecked(bool value) =>
      state = state.copyWith(restrictionChecked: value);

  /// @brief 按 ID 新增或替换演示餐食，并将现有报告标记为过期。
  /// @param meal 待保存的餐食条目。
  void saveMeal(MealEntry meal) => state = state.copyWith(
    // ... 展开原有元素：先排除相同 ID，再把新餐食放到列表末尾。
    meals: [...state.meals.where((m) => m.id != meal.id), meal],
    reports: state.reports.map((r) => r.copyWith(stale: true)).toList(),
  );

  /// @brief 按 ID 移除指定演示餐食，并将已有报告标记为过期。
  /// @param id 待移除的餐食 ID。
  void removeMeal(String id) => state = state.copyWith(
    meals: state.meals.where((m) => m.id != id).toList(),
    reports: state.reports.map((r) => r.copyWith(stale: true)).toList(),
  );

  /// @brief 按 ID 新增或替换一条健康记录预览。
  /// @param entry 待保存的健康记录预览条目。
  void saveHealthRecord(HealthRecordPreview entry) => state = state.copyWith(
    healthRecords: [
      ...state.healthRecords.where((r) => r.id != entry.id),
      entry,
    ],
  );

  /// @brief 按 ID 删除指定的健康记录预览。
  /// @param id 待删除的健康记录 ID。
  void removeHealthRecord(String id) => state = state.copyWith(
    healthRecords: state.healthRecords.where((r) => r.id != id).toList(),
  );

  /// @brief 确认机构演示餐并按食用比例写入演示餐食记录。
  /// @param fraction 实际食用比例，取值范围为 (0, 1]，例如 0.5 表示吃了半份。
  void confirmInstitutionMeal({required double fraction}) {
    // 尚未核对限制、已确认过或比例不在 (0, 1] 内时，直接结束。
    if (!state.restrictionChecked ||
        state.institutionConfirmed ||
        fraction <= 0 ||
        fraction > 1) {
      return;
    }
    // 使用固定演示餐和日期，能量、蛋白质按食用比例折算。
    final meal = MealEntry(
      id: 'institution-dinner',
      title: '清蒸鱼套餐',
      type: MealType.dinner,
      consumedAt: DateTime(2026, 10, 2, 18),
      nutrients: Nutrients(energy: 520 * fraction, protein: 38 * fraction),
      source: RecordSource.institution,
      notes: '本人归属与实际食用量已在演示中核对',
    );
    // 先保存餐食并标记报告过期，再记录“机构餐已确认”。
    saveMeal(meal);
    state = state.copyWith(institutionConfirmed: true);
  }

  /// @brief 根据演示日期最近七天的已知每日能量值生成一条本地报告预览。
  void generateReport() {
    final values = state
        .trend(7)
        .map((p) => p.nutrients.energy)
        .whereType<double>()
        .toList();
    // 只对能量已知的天数求平均，不固定除以 7；全部未知时这里使用 0.0。
    final average = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a + b) / values.length;
    // 根据已有 weekly 报告数量生成下一个演示版本号。
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
        // 新报告放最前面，保留此前的报告。
        ...state.reports,
      ],
    );
  }

  /// @brief 恢复全部默认演示样例，同时保留当前选择的个人或机构模式。
  void reset() => state = DemoSnapshot(meals: initialMeals(), mode: state.mode);
}

/// @brief 全局演示状态 Provider，注册 DemoController 与 DemoSnapshot。
/// @details 两个泛型参数依次表示管理状态的控制器类型和对外提供的状态类型；DemoController.new 由 Riverpod 在需要时创建控制器。
/// @code{.dart}
/// final snapshot = ref.watch(demoProvider); // 读取并订阅 DemoSnapshot。
/// final controller = ref.read(demoProvider.notifier); // 取得 DemoController。
/// controller.selectPlan('fish'); // 调用方法，更新 state 后通知监听者。
/// @endcode
final demoProvider = NotifierProvider<DemoController, DemoSnapshot>(
  DemoController.new,
);
