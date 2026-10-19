enum ExperienceMode { personal, institution }

enum AnalysisStatus { pending, analyzing, ready, failed }

extension AnalysisStatusLabel on AnalysisStatus {
  String get label => switch (this) {
    AnalysisStatus.pending => '待分析',
    AnalysisStatus.analyzing => '分析中',
    AnalysisStatus.ready => '已分析',
    AnalysisStatus.failed => '分析失败',
  };
}

enum MealType { breakfast, lunch, dinner, snack, other }

extension MealTypeLabel on MealType {
  String get label => switch (this) {
    MealType.breakfast => '早餐',
    MealType.lunch => '午餐',
    MealType.dinner => '晚餐',
    MealType.snack => '加餐',
    MealType.other => '其他',
  };
}

enum RecordSource { photo, manual, institution }

extension RecordSourceLabel on RecordSource {
  String get label => switch (this) {
    RecordSource.photo => 'AI 估算',
    RecordSource.manual => '人工记录',
    RecordSource.institution => '机构配方 · 演示',
  };
}

class Nutrients {
  const Nutrients({
    this.energy,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.sodium,
  });
  final double? energy;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final double? sodium;
  double? value(String code) => switch (code) {
    'energy' => energy,
    'protein' => protein,
    'carbs' => carbs,
    'fat' => fat,
    'fiber' => fiber,
    'sodium' => sodium,
    _ => null,
  };
}

class FoodPortion {
  const FoodPortion({
    required this.id,
    required this.name,
    required this.grams,
    this.nutrients = const Nutrients(),
  });
  final String id;
  final String name;
  final double grams;
  final Nutrients nutrients;
  FoodPortion copyWith({String? name, double? grams, Nutrients? nutrients}) =>
      FoodPortion(
        id: id,
        name: name ?? this.name,
        grams: grams ?? this.grams,
        nutrients: nutrients ?? this.nutrients,
      );
}

class MealEntry {
  const MealEntry({
    required this.id,
    required this.title,
    required this.type,
    required this.consumedAt,
    required this.nutrients,
    this.status = AnalysisStatus.ready,
    this.source = RecordSource.photo,
    this.foods = const [],
    this.notes = '',
    this.confirmed = true,
  });
  final String id;
  final String title;
  final MealType type;
  final DateTime consumedAt;
  final Nutrients nutrients;
  final AnalysisStatus status;
  final RecordSource source;
  final List<FoodPortion> foods;
  final String notes;
  final bool confirmed;
  MealEntry copyWith({
    String? title,
    MealType? type,
    DateTime? consumedAt,
    Nutrients? nutrients,
    AnalysisStatus? status,
    RecordSource? source,
    List<FoodPortion>? foods,
    String? notes,
    bool? confirmed,
  }) => MealEntry(
    id: id,
    title: title ?? this.title,
    type: type ?? this.type,
    consumedAt: consumedAt ?? this.consumedAt,
    nutrients: nutrients ?? this.nutrients,
    status: status ?? this.status,
    source: source ?? this.source,
    foods: List.unmodifiable(foods ?? this.foods),
    notes: notes ?? this.notes,
    confirmed: confirmed ?? this.confirmed,
  );
}

class PlanOption {
  const PlanOption({
    required this.id,
    required this.name,
    required this.energy,
    required this.protein,
    required this.minutes,
    required this.foods,
    required this.reason,
  });
  final String id;
  final String name;
  final double energy;
  final double protein;
  final int minutes;
  final List<FoodPortion> foods;
  final String reason;
}

class PersonProfile {
  const PersonProfile({
    this.name = '林知夏',
    this.email = 'lin***@mail.com',
    this.birthday = '1994.04.18',
    this.gender = '女',
    this.height = 164,
    this.weight = 58.4,
    this.activity = '轻度活动',
    this.waterGoal = 1600,
    this.goal = '维持体重',
  });
  final String name;
  final String email;
  final String birthday;
  final String gender;
  final double height;
  final double weight;
  final String activity;
  final int waterGoal;
  final String goal;
  PersonProfile copyWith({
    String? name,
    String? email,
    String? birthday,
    String? gender,
    double? height,
    double? weight,
    String? activity,
    int? waterGoal,
    String? goal,
  }) => PersonProfile(
    name: name ?? this.name,
    email: email ?? this.email,
    birthday: birthday ?? this.birthday,
    gender: gender ?? this.gender,
    height: height ?? this.height,
    weight: weight ?? this.weight,
    activity: activity ?? this.activity,
    waterGoal: waterGoal ?? this.waterGoal,
    goal: goal ?? this.goal,
  );
}

class HealthRecordPreview {
  const HealthRecordPreview({
    required this.id,
    required this.kind,
    required this.title,
    required this.value,
    this.note = '',
    this.date = '2026-10-01',
  });
  final String id;
  final String kind;
  final String title;
  final String value;
  final String note;
  final String date;
}

class ReportPreview {
  const ReportPreview({
    required this.id,
    required this.title,
    required this.period,
    required this.average,
    required this.version,
    this.stale = false,
  });
  final String id;
  final String title;
  final String period;
  final double average;
  final int version;
  final bool stale;
  ReportPreview copyWith({bool? stale}) => ReportPreview(
    id: id,
    title: title,
    period: period,
    average: average,
    version: version,
    stale: stale ?? this.stale,
  );
}

class TrendPoint {
  const TrendPoint({
    required this.date,
    required this.nutrients,
    this.recordCount = 0,
    this.analyzingCount = 0,
  });
  final DateTime date;
  final Nutrients nutrients;
  final int recordCount;
  final int analyzingCount;
}

String formatAmount(double? value, {String unknown = '待补充'}) {
  if (value == null) return unknown;
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
