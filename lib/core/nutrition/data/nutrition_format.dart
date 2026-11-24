/// 餐别编码到中文标签的统一映射表。
const Map<String, String> kMealTypeLabels = {
  'breakfast': '早餐',
  'lunch': '午餐',
  'dinner': '晚餐',
  'snack': '加餐',
  'other': '其他',
};

/// 有序餐别编码列表（与 [kMealTypeLabels] 对应）。
const List<String> kMealTypeKeys = [
  'breakfast',
  'lunch',
  'dinner',
  'snack',
  'other',
];

/// 有序餐别中文标签列表（与 [kMealTypeKeys] 对应）。
const List<String> kMealTypeDisplayLabels = ['早餐', '午餐', '晚餐', '加餐', '其他'];

/// 核心宏观营养素展示元数据（编码、中文名、单位）。
const List<(String code, String label, String unit)> kCoreNutrientFields = [
  ('ENERGY_KCAL', '能量', 'kcal'),
  ('PROTEIN', '蛋白质', 'g'),
  ('CARBOHYDRATE', '碳水', 'g'),
  ('FAT', '脂肪', 'g'),
];

/// 餐食修正表单常用营养素输入标签映射。
const Map<String, String> kEditableNutrientLabels = {
  'ENERGY_KCAL': '能量 (kcal)',
  'PROTEIN': '蛋白质 (g)',
  'CARBOHYDRATE': '碳水 (g)',
  'FAT': '脂肪 (g)',
  'DIETARY_FIBER': '膳食纤维 (g)',
  'SODIUM': '钠 (mg)',
};

/// 将日期格式化为 `YYYY-MM-DD` 协议字符串。
String formatIsoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// 将本地时刻格式化为 `HH:mm`。
String formatLocalTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

/// 将本地日期与时刻格式化为 `YYYY-MM-DD HH:mm`。
String formatLocalDateTimeMinute(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${formatIsoDate(local)} ${formatLocalTime(local)}';
}

/// 将餐别编码转换为中文名称；未知编码原样返回。
String mealTypeLabel(String type) => kMealTypeLabels[type] ?? type;

/// 将餐食分析状态编码转换为中文展示标签。
///
/// [queuedLabel] 用于兼容首页“待分析”与详情/历史“等待分析”的文案差异。
String analysisStatusLabel(String status, {String queuedLabel = '等待分析'}) =>
    switch (status) {
      'queued' || 'pending' => queuedLabel,
      'analysing' || 'analyzing' => '分析中',
      'completed' => '已分析',
      'failed' => '分析失败',
      'needs_review' => '需要核对',
      _ => status,
    };

/// 将采集草稿状态编码转换为中文展示标签。
String captureStatusLabel(String status) => switch (status) {
  'created' => '已创建，待选择图片',
  'uploading' => '待完成图片确认',
  'submitted' => '已提交分析',
  'failed' => '分析失败，可重新发起',
  'completed' => '已完成',
  _ => status,
};

/// 格式化营养数值；缺失显示 [unknown]，整数去掉小数点。
String formatNutrientAmount(double? amount, {String unknown = '未知'}) =>
    amount == null
    ? unknown
    : amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
