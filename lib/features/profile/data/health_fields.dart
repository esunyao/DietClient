/// Orion 的五类记录字段，表单和验证共用同一契约映射。
class HealthField {
  const HealthField(
    this.key,
    this.label, {
    this.required = false,
    this.min,
    this.max,
    this.integer = false,
    this.options,
    this.date = false,
    this.dateTime = false,
    this.maxLength = 500,
  });
  final String key, label;
  final bool required, integer, date, dateTime;
  final double? min, max;
  final Map<String, String>? options;
  final int maxLength;
}

const measurementSources = {
  'manual': '手工测量',
  'device': '设备',
  'import': '导入',
  'clinical': '临床',
};
const fieldsByKind = <String, List<HealthField>>{
  'measurement': [
    HealthField('measuredAt', '测量时间', dateTime: true),
    HealthField('heightCm', '身高（cm）', min: 50, max: 300),
    HealthField('weightKg', '体重（kg）', min: 10, max: 500),
    HealthField('bodyFatPercentage', '体脂率（%）', min: 0, max: 100),
    HealthField('waistCm', '腰围（cm）', min: 20, max: 300),
    HealthField('systolicBp', '收缩压（mmHg）', min: 40, max: 300, integer: true),
    HealthField('diastolicBp', '舒张压（mmHg）', min: 20, max: 200, integer: true),
    HealthField(
      'restingHeartRate',
      '静息心率（次/分）',
      min: 20,
      max: 250,
      integer: true,
    ),
    HealthField('source', '来源', options: measurementSources),
    HealthField('sourceReference', '来源参考', maxLength: 255),
    HealthField('notes', '备注'),
  ],
  'goal': [
    HealthField(
      'goalType',
      '目标类型',
      required: true,
      options: {
        'weight_loss': '减重',
        'muscle_gain': '增肌',
        'maintain': '维持',
        'health_improve': '改善健康',
      },
    ),
    HealthField('targetWeightKg', '目标体重（kg）', min: 10, max: 500),
    HealthField('targetBodyFatPercentage', '目标体脂率（%）', min: 0, max: 100),
    HealthField('priority', '优先级（1–10）', min: 1, max: 10, integer: true),
    HealthField(
      'status',
      '目标状态',
      options: {
        'planned': '计划中',
        'active': '进行中',
        'achieved': '已达成',
        'cancelled': '已取消',
      },
    ),
    HealthField('startedOn', '开始日期', date: true),
    HealthField('targetDate', '目标日期', date: true),
    HealthField('notes', '备注'),
  ],
  'allergy': [
    HealthField('allergenCode', '过敏原代码', required: true, maxLength: 64),
    HealthField('allergenName', '过敏原名称', required: true, maxLength: 100),
    HealthField(
      'severity',
      '严重程度',
      options: {
        'mild': '轻度',
        'moderate': '中度',
        'severe': '重度',
        'life_threatening': '危及生命',
      },
    ),
    HealthField('reactionDescription', '反应描述'),
    HealthField(
      'diagnosisStatus',
      '诊断状态',
      options: {'self_reported': '自述', 'suspected': '疑似', 'confirmed': '已确诊'},
    ),
    HealthField('recordedOn', '记录日期', date: true),
    HealthField('active', '是否有效', options: {'true': '有效', 'false': '已停用'}),
    HealthField('notes', '备注'),
  ],
  'disease': [
    HealthField('conditionCode', '疾病代码', required: true, maxLength: 64),
    HealthField('conditionName', '疾病名称', required: true, maxLength: 150),
    HealthField(
      'status',
      '疾病状态',
      options: {'active': '活动期', 'remission': '缓解期', 'resolved': '已解除'},
    ),
    HealthField('diagnosedOn', '诊断日期', date: true),
    HealthField('resolvedOn', '解除日期', date: true),
    HealthField(
      'source',
      '来源',
      options: {'self_reported': '自述', 'clinical': '临床', 'imported': '导入'},
    ),
    HealthField('notes', '备注'),
  ],
  'restriction': [
    HealthField('restrictionCode', '限制代码', required: true, maxLength: 64),
    HealthField('restrictionName', '限制名称', required: true, maxLength: 100),
    HealthField(
      'category',
      '限制类别',
      required: true,
      options: {
        'medical': '医疗',
        'religious': '宗教',
        'lifestyle': '生活方式',
        'preference': '个人偏好',
      },
    ),
    HealthField(
      'source',
      '来源',
      options: {'self_reported': '自述', 'clinician': '医生', 'system': '系统'},
    ),
    HealthField('active', '是否有效', options: {'true': '有效', 'false': '已停用'}),
    HealthField('startsOn', '开始日期', date: true),
    HealthField('endsOn', '结束日期', date: true),
    HealthField('notes', '备注'),
  ],
};

String? validateHealthField(HealthField field, String value) {
  if (value.isEmpty) return field.required ? '请填写${field.label}' : null;
  if (value.length > field.maxLength) return '最多 ${field.maxLength} 字符';
  if (field.min != null) {
    final number = num.tryParse(value);
    if (number == null ||
        !number.isFinite ||
        number < field.min! ||
        number > field.max! ||
        (field.integer && int.tryParse(value) == null)) {
      return '请输入 ${field.min}–${field.max}${field.integer ? ' 的整数' : ''}';
    }
  }
  if (field.date || field.dateTime) {
    final date = DateTime.tryParse(value);
    if (date == null ||
        (field.date &&
            (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
                date.toIso8601String().substring(0, 10) != value))) {
      return '请输入有效日期 YYYY-MM-DD';
    }
    if (field.dateTime &&
        (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value) ||
            date.isAfter(DateTime.now().add(const Duration(minutes: 5))))) {
      return '请输入不晚于当前时间且含时区的时间';
    }
  }
  return null;
}

String? validateHealthDates(String kind, Map<String, dynamic> data) {
  final pairs = {
    'goal': ['startedOn', 'targetDate'],
    'disease': ['diagnosedOn', 'resolvedOn'],
    'restriction': ['startsOn', 'endsOn'],
  };
  final pair = pairs[kind];
  if (pair != null &&
      data[pair[0]] != null &&
      data[pair[1]] != null &&
      DateTime.parse(data[pair[1]] as String)
          .isBefore(DateTime.parse(data[pair[0]] as String))) {
    return '结束日期不能早于开始日期';
  }
  if (kind == 'measurement' &&
      !fieldsByKind[kind]!
          .where((f) => f.min != null)
          .any((f) => data[f.key] != null)) {
    return '请至少填写一个测量指标';
  }
  return null;
}
