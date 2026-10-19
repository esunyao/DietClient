import 'package:diet_models/diet_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_fixtures.dart';

export 'demo_fixtures.dart';

export 'package:diet_models/diet_models.dart';

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
  final List<MealEntry> meals;
  final ExperienceMode mode;
  final PersonProfile profile;
  final String selectedPlanId;
  final bool planSaved;
  final bool aiConsent;
  final bool institutionConfirmed;
  final bool restrictionChecked;
  final bool privacyHidden;
  final List<HealthRecordPreview> healthRecords;
  final List<ReportPreview> reports;
  bool get isInstitution => mode == ExperienceMode.institution;
  PlanOption get selectedPlan =>
      demoPlans.firstWhere((p) => p.id == selectedPlanId);
  List<MealEntry> get todayMeals =>
      meals.where((m) => sameDay(m.consumedAt, demoDate)).toList()
        ..sort((a, b) => a.consumedAt.compareTo(b.consumedAt));
  Nutrients get todayTotal => totalFor(todayMeals);
  MealEntry? meal(String id) {
    for (final entry in meals) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  List<TrendPoint> trend(int days) => List.generate(days, (i) {
    final date = demoDate.subtract(Duration(days: days - i - 1));
    final entries = meals.where((m) => sameDay(m.consumedAt, date)).toList();
    return TrendPoint(
      date: date,
      nutrients: totalFor(entries),
      recordCount: entries.length,
      analyzingCount: entries
          .where((e) => e.status == AnalysisStatus.analyzing)
          .length,
    );
  });
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

Nutrients totalFor(Iterable<MealEntry> entries) {
  final ready = entries
      .where((e) => e.confirmed && e.status == AnalysisStatus.ready)
      .toList();
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

class DemoController extends Notifier<DemoSnapshot> {
  @override
  DemoSnapshot build() => DemoSnapshot(meals: initialMeals());
  void selectMode(ExperienceMode mode) =>
      state = DemoSnapshot(meals: initialMeals(), mode: mode);
  void updateProfile(PersonProfile profile) =>
      state = state.copyWith(profile: profile);
  void selectPlan(String id) {
    if (demoPlans.any((p) => p.id == id)) {
      state = state.copyWith(selectedPlanId: id, planSaved: false);
    }
  }

  void savePlan() => state = state.copyWith(planSaved: true);
  void setAiConsent(bool value) => state = state.copyWith(aiConsent: value);
  void setPrivacyHidden(bool value) =>
      state = state.copyWith(privacyHidden: value);
  void setRestrictionChecked(bool value) =>
      state = state.copyWith(restrictionChecked: value);
  void saveMeal(MealEntry meal) => state = state.copyWith(
    meals: [...state.meals.where((m) => m.id != meal.id), meal],
    reports: state.reports.map((r) => r.copyWith(stale: true)).toList(),
  );
  void removeMeal(String id) => state = state.copyWith(
    meals: state.meals.where((m) => m.id != id).toList(),
    reports: state.reports.map((r) => r.copyWith(stale: true)).toList(),
  );
  void saveHealthRecord(HealthRecordPreview entry) => state = state.copyWith(
    healthRecords: [
      ...state.healthRecords.where((r) => r.id != entry.id),
      entry,
    ],
  );
  void removeHealthRecord(String id) => state = state.copyWith(
    healthRecords: state.healthRecords.where((r) => r.id != id).toList(),
  );
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

  void reset() => state = DemoSnapshot(meals: initialMeals(), mode: state.mode);
}

final demoProvider = NotifierProvider<DemoController, DemoSnapshot>(
  DemoController.new,
);
