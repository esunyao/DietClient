import { memo, useCallback, useMemo, useState } from 'react';
import { FlatList, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ChevronRight, Star, Trash2 } from 'lucide-react-native';
import type { ProfileStackParamList } from '../../../navigation/types';
import { getErrorMessage } from '../../../shared/api/client';
import { PressableScale } from '../../../shared/animation/PressableScale';
import {
  AppButton,
  AppScreen,
  DateWheelField,
  DestructiveConfirmSheet,
  EmptyState,
  GlassCard,
  HealthPickerSheet,
  HealthSelectField,
  NumericWheelField,
  PercentageSliderField,
  ScreenHeader,
  SectionTitle,
  WeightWheelField,
  inputStyle,
  type HealthPickerOption,
} from '../../../shared/components';
import { PerfRegion } from '../../../shared/perf/PerfRegion';
import { scheduleIdleTask } from '../../../shared/perf/scheduleIdleTask';
import { colors, fonts, radii, spacing } from '../../../shared/theme/tokens';
import type {
  Allergy,
  BodyMeasurement,
  DietaryRestriction,
  HealthGoal,
  MedicalCondition,
} from '../api/profileTypes';
import {
  normalizePercentageInput,
  PERCENTAGE_VALIDATION_MESSAGE,
} from '../../../shared/validation/percentage';
import { useToast } from '../../../shared/components';
import { healthApi } from '../api/healthApi';
import {
  getHealthRecordId,
  getHealthRecordDeleteSummary,
  listHealthRecords,
  removeHealthRecord,
  upsertHealthRecord,
} from '../services/healthRecords';
type FormProps = NativeStackScreenProps<ProfileStackParamList, 'HealthRecordForm'>;
type Kind = FormProps['route']['params']['kind'];
const kindTitle: Record<Kind, string> = {
  measurement: '身体测量',
  goal: '健康目标',
  allergy: '过敏记录',
  condition: '疾病记录',
  restriction: '饮食限制',
};
function formatDate(value?: string | null): string {
  return value ? value.slice(0, 10) : '未填写';
}
function customCode(): string {
  return `custom-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}
type RecordBadge = {
  label: string;
  tone?: 'blue' | 'amber' | 'red' | 'green' | 'plain';
};
const severityLabel = {
  mild: '轻微',
  moderate: '中等',
  severe: '严重',
  life_threatening: '危及生命',
};
const diagnosisLabel = {
  self_reported: '自行记录',
  suspected: '疑似',
  confirmed: '已确认',
};
const conditionLabel = {
  active: '进行中',
  remission: '缓解',
  resolved: '已解决',
};
const restrictionLabel = {
  medical: '医疗',
  religious: '宗教',
  lifestyle: '生活方式',
  preference: '个人偏好',
};
const goalLabel = {
  weight_loss: '减重',
  muscle_gain: '增肌',
  maintain: '保持',
  health_improve: '改善健康',
};
function recordPresentation(
  kind: Kind,
  item: BodyMeasurement | HealthGoal | Allergy | MedicalCondition | DietaryRestriction,
): {
  title: string;
  detail: string;
  badges: RecordBadge[];
} {
  if (kind === 'measurement') {
    const record = item as BodyMeasurement;
    return {
      title: '身体测量',
      detail: `测量于 ${formatDate(record.measuredAt)}`,
      badges: [
        {
          label: record.weightKg == null ? '未填体重' : `${record.weightKg} kg`,
          tone: 'blue',
        },
        ...(record.bodyFatPercentage == null
          ? []
          : [
              {
                label: `${record.bodyFatPercentage}% 体脂`,
                tone: 'plain' as const,
              },
            ]),
      ],
    };
  }
  if (kind === 'goal') {
    const record = item as HealthGoal;
    const status =
      record.status === 'active'
        ? '进行中'
        : record.status === 'planned'
        ? '计划中'
        : record.status === 'achieved'
        ? '已完成'
        : '已取消';
    return {
      title: goalLabel[record.goalType],
      detail: record.targetDate
        ? `目标日期 ${formatDate(record.targetDate)}`
        : '可随时补充目标期限',
      badges: [
        {
          label: status,
          tone:
            record.status === 'achieved'
              ? 'green'
              : record.status === 'cancelled'
              ? 'red'
              : record.status === 'planned'
              ? 'plain'
              : 'blue',
        },
        ...(record.targetWeightKg == null
          ? []
          : [
              {
                label: `${record.targetWeightKg} kg`,
                tone: 'plain' as const,
              },
            ]),
      ],
    };
  }
  if (kind === 'allergy') {
    const record = item as Allergy;
    const severity = record.severity ?? 'mild';
    return {
      title: record.allergenName,
      detail: record.recordedOn ? `记录于 ${formatDate(record.recordedOn)}` : '尚未填写记录日期',
      badges: [
        {
          label: severityLabel[severity],
          tone:
            severity === 'life_threatening' || severity === 'severe'
              ? 'red'
              : severity === 'moderate'
              ? 'amber'
              : 'blue',
        },
        {
          label: diagnosisLabel[record.diagnosisStatus],
          tone: 'plain',
        },
      ],
    };
  }
  if (kind === 'condition') {
    const record = item as MedicalCondition;
    return {
      title: record.conditionName,
      detail: record.diagnosedOn ? `诊断于 ${formatDate(record.diagnosedOn)}` : '尚未填写诊断日期',
      badges: [
        {
          label: conditionLabel[record.status],
          tone:
            record.status === 'resolved' ? 'green' : record.status === 'active' ? 'red' : 'amber',
        },
      ],
    };
  }
  const record = item as DietaryRestriction;
  return {
    title: record.restrictionName,
    detail: record.startsOn ? `生效于 ${formatDate(record.startsOn)}` : '尚未填写生效日期',
    badges: [
      {
        label: restrictionLabel[record.category],
        tone: 'plain',
      },
      {
        label: record.active ? '生效中' : '已结束',
        tone: record.active ? 'green' : 'plain',
      },
    ],
  };
}
const RecordRow = memo(function ({
  title,
  detail,
  badges,
  onPress,
}: {
  title: string;
  detail: string;
  badges: RecordBadge[];
  onPress: () => void;
}) {
  return (
    <PressableScale accessibilityRole="button" onPress={onPress} style={styles.recordRow}>
      <View style={styles.recordRowCopy}>
        <Text numberOfLines={1} style={styles.rowTitle}>
          {title}
        </Text>
        <Text numberOfLines={1} style={styles.rowDetail}>
          {detail}
        </Text>
      </View>
      <View style={styles.recordBadges}>
        {badges.slice(0, 2).map(badge => (
          <View
            key={badge.label}
            style={[
              styles.recordBadge,
              badge.tone === 'amber' && styles.recordBadgeAmber,
              badge.tone === 'red' && styles.recordBadgeRed,
              badge.tone === 'green' && styles.recordBadgeGreen,
              badge.tone === 'plain' && styles.recordBadgePlain,
            ]}
          >
            <Text
              numberOfLines={1}
              style={[
                styles.recordBadgeText,
                badge.tone === 'amber' && styles.recordBadgeAmberText,
                badge.tone === 'red' && styles.recordBadgeRedText,
                badge.tone === 'green' && styles.recordBadgeGreenText,
                badge.tone === 'plain' && styles.recordBadgePlainText,
              ]}
            >
              {badge.label}
            </Text>
          </View>
        ))}
      </View>
      <ChevronRight color={colors.muted} size={17} />
    </PressableScale>
  );
});
function Field({
  label,
  value,
  onChange,
  placeholder,
  numeric = false,
  multiline = false,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  numeric?: boolean;
  multiline?: boolean;
}) {
  const wheel =
    label === '体重 (kg)'
      ? {
          label: '体重',
          minimum: 10,
          maximum: 500,
          step: 0.1,
          unit: 'kg',
        }
      : label === '腰围 (cm)'
      ? {
          label: '腰围',
          minimum: 20,
          maximum: 300,
          step: 0.1,
          unit: 'cm',
        }
      : label === '本次身高 (cm)'
      ? {
          label: '本次身高',
          minimum: 50,
          maximum: 300,
          step: 0.1,
          unit: 'cm',
        }
      : label === '收缩压 (mmHg)'
      ? {
          label: '收缩压',
          minimum: 40,
          maximum: 300,
          step: 1,
          unit: 'mmHg',
        }
      : label === '舒张压 (mmHg)'
      ? {
          label: '舒张压',
          minimum: 20,
          maximum: 200,
          step: 1,
          unit: 'mmHg',
        }
      : label === '静息心率 (bpm)'
      ? {
          label: '静息心率',
          minimum: 20,
          maximum: 250,
          step: 1,
          unit: 'bpm',
        }
      : null;
  if (wheel) return <NumericWheelField {...wheel} onChange={onChange} value={value} />;
  return (
    <View style={styles.field}>
      <Text style={styles.fieldLabel}>{label}</Text>
      <TextInput
        accessibilityLabel={label}
        keyboardType={numeric ? 'decimal-pad' : 'default'}
        multiline={multiline}
        onChangeText={onChange}
        placeholder={placeholder}
        placeholderTextColor="#94A3B8"
        style={[inputStyle, multiline && styles.multiline]}
        value={value}
      />
    </View>
  );
}
function DateField({
  label,
  value,
  onChange,
  mode = 'date',
  optional = false,
  minimumDate,
  maximumDate,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  mode?: 'date' | 'datetime';
  optional?: boolean;
  minimumDate?: Date;
  maximumDate?: Date;
}) {
  return (
    <DateWheelField
      label={label}
      maximumDate={maximumDate}
      minimumDate={minimumDate}
      mode={mode}
      optional={optional}
      value={value}
      onChange={onChange}
    />
  );
}
function Choices({
  label,
  value,
  values,
  onChange,
}: {
  label: string;
  value: string;
  values: Array<[string, string]>;
  onChange: (value: string) => void;
}) {
  return (
    <HealthSelectField
      label={label}
      onChange={onChange}
      options={
        values.map(([itemValue, itemLabel]) => ({
          value: itemValue,
          label: itemLabel,
        })) as HealthPickerOption[]
      }
      value={value}
    />
  );
}
function asNumber(value: string): number | undefined {
  const number = Number(value);
  return value.trim() && Number.isFinite(number) ? number : undefined;
}
function isWeight(value: string): boolean {
  const number = Number(value);
  return /^\d{1,3}(?:\.\d)?$/.test(value) && number >= 10 && number <= 500;
}
function PriorityRating({ value, onChange }: { value: string; onChange: (value: string) => void }) {
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState(value);
  const score = Math.max(1, Math.min(10, Number(value) || 1));
  const draftScore = Math.max(1, Math.min(10, Number(draft) || 1));
  const stars = (
    <View accessibilityLabel={`当前优先级 ${draftScore} 分`} style={styles.stars}>
      {Array.from(
        {
          length: 5,
        },
        (_, index) => {
          const filledPercent = Math.max(0, Math.min(100, (draftScore - index * 2) * 50));
          return (
            <View key={index} style={styles.starHitArea}>
              <Star color="#F0A000" fill="transparent" size={31} strokeWidth={1.8} />
              {filledPercent > 0 ? (
                <View
                  pointerEvents="none"
                  style={[
                    styles.starFill,
                    {
                      width: `${filledPercent}%`,
                    },
                  ]}
                >
                  <Star color="#F0A000" fill="#FFD166" size={31} strokeWidth={1.8} />
                </View>
              ) : null}
              <Pressable
                accessibilityLabel={`优先级 ${index * 2 + 1} 分`}
                accessibilityRole="button"
                onPress={() => setDraft(String(index * 2 + 1))}
                style={styles.starHalfLeft}
              />
              <Pressable
                accessibilityLabel={`优先级 ${index * 2 + 2} 分`}
                accessibilityRole="button"
                onPress={() => setDraft(String(index * 2 + 2))}
                style={styles.starHalfRight}
              />
            </View>
          );
        },
      )}
    </View>
  );
  return (
    <View style={styles.field}>
      <Text style={styles.fieldLabel}>优先级</Text>
      <Pressable
        onPress={() => {
          setDraft(value);
          setOpen(true);
        }}
        style={styles.selectValueCard}
      >
        <Text style={styles.selectValue}>{score}/10 分</Text>
        <ChevronRight color={colors.blue} size={18} />
      </Pressable>
      <HealthPickerSheet
        confirmLabel="保存优先级"
        onCancel={() => setOpen(false)}
        onConfirm={() => {
          onChange(draft);
          setOpen(false);
        }}
        title="目标优先级"
        value={value}
        visible={open}
      >
        <View style={styles.ratingSheet}>
          <Text style={styles.sheetMetric}>{draftScore}/10 分</Text>
          {stars}
          <Text style={styles.fieldHint}>轻点星星左半或右半，选择 1–10 分。</Text>
        </View>
      </HealthPickerSheet>
    </View>
  );
}
function initialValues(
  kind: Kind,
  record?: BodyMeasurement | HealthGoal | Allergy | MedicalCondition | DietaryRestriction,
): Record<string, string> {
  if (!record)
    return kind === 'measurement'
      ? {
          measuredAt: new Date().toISOString(),
          heightCm: '',
          weightKg: '',
          bodyFatPercentage: '',
          waistCm: '',
          systolicBp: '',
          diastolicBp: '',
          restingHeartRate: '',
          notes: '',
        }
      : kind === 'goal'
      ? {
          goalType: 'health_improve',
          targetWeightKg: '',
          targetBodyFatPercentage: '',
          priority: '1',
          status: 'active',
          startedOn: new Date().toISOString().slice(0, 10),
          targetDate: '',
          notes: '',
        }
      : kind === 'allergy'
      ? {
          allergenName: '',
          severity: 'mild',
          diagnosisStatus: 'self_reported',
          recordedOn: '',
          notes: '',
        }
      : kind === 'condition'
      ? {
          conditionName: '',
          status: 'active',
          diagnosedOn: '',
          resolvedOn: '',
          notes: '',
        }
      : {
          restrictionName: '',
          category: 'preference',
          startsOn: '',
          endsOn: '',
          notes: '',
        };
  if (kind === 'measurement') {
    const item = record as BodyMeasurement;
    return {
      measuredAt: item.measuredAt,
      heightCm: String(item.heightCm ?? ''),
      weightKg: String(item.weightKg ?? ''),
      bodyFatPercentage: String(item.bodyFatPercentage ?? ''),
      waistCm: String(item.waistCm ?? ''),
      systolicBp: String(item.systolicBp ?? ''),
      diastolicBp: String(item.diastolicBp ?? ''),
      restingHeartRate: String(item.restingHeartRate ?? ''),
      notes: item.notes ?? '',
    };
  }
  if (kind === 'goal') {
    const item = record as HealthGoal;
    return {
      goalType: item.goalType,
      targetWeightKg: String(item.targetWeightKg ?? ''),
      targetBodyFatPercentage: String(item.targetBodyFatPercentage ?? ''),
      priority: String(item.priority),
      status: item.status,
      startedOn: item.startedOn,
      targetDate: item.targetDate ?? '',
      notes: item.notes ?? '',
    };
  }
  if (kind === 'allergy') {
    const item = record as Allergy;
    return {
      allergenName: item.allergenName,
      severity: item.severity ?? 'mild',
      diagnosisStatus: item.diagnosisStatus,
      recordedOn: item.recordedOn ?? '',
      notes: item.notes ?? '',
    };
  }
  if (kind === 'condition') {
    const item = record as MedicalCondition;
    return {
      conditionName: item.conditionName,
      status: item.status,
      diagnosedOn: item.diagnosedOn ?? '',
      resolvedOn: item.resolvedOn ?? '',
      notes: item.notes ?? '',
    };
  }
  const item = record as DietaryRestriction;
  return {
    restrictionName: item.restrictionName,
    category: item.category,
    startsOn: item.startsOn ?? '',
    endsOn: item.endsOn ?? '',
    notes: item.notes ?? '',
  };
}
export function HealthRecordFormScreen({ navigation, route }: FormProps) {
  const { show } = useToast();
  const { kind, id } = route.params;
  const [records, setRecords] = useState<
    Array<BodyMeasurement | HealthGoal | Allergy | MedicalCondition | DietaryRestriction>
  >([]);
  const [values, setValues] = useState<Record<string, string>>(initialValues(kind));
  const [saving, setSaving] = useState(false);
  const [deleteSheetVisible, setDeleteSheetVisible] = useState(false);
  const [recordState, setRecordState] = useState<'loading' | 'ready' | 'missing' | 'error'>(
    id ? 'loading' : 'ready',
  );
  const current = useMemo(
    () => records.find(item => getHealthRecordId(kind, item) === id),
    [id, kind, records],
  );
  const set = (key: string) => (value: string) =>
    setValues(previous => ({
      ...previous,
      [key]: value,
    }));
  const loadRecords = useCallback(() => {
    listHealthRecords(kind)
      .then(result => {
        // 编辑记录的 code 必须立即可用；这里的列表最多是单一类别，直接提交状态比延迟
        // transition 更可靠，避免刚进入编辑页就保存时丢失原有自定义 code。
        setRecords(result);
        const found = result.find(item => getHealthRecordId(kind, item) === id);
        if (id && !found) {
          setRecordState('missing');
          show('该记录已不存在，已返回列表', 'error');
          navigation.goBack();
          return;
        }
        if (found) setValues(initialValues(kind, found));
        setRecordState('ready');
      })
      .catch(error => {
        if (id) setRecordState('error');
        show(getErrorMessage(error), 'error');
      });
  }, [id, kind, navigation, show]);

  // 与 HealthRecordsScreen 一致：等导航转场动画结束再发请求，避免与渲染竞争 JS 线程。
  useFocusEffect(
    useCallback(() => {
      const cancel = scheduleIdleTask(() => {
        loadRecords();
      });
      return cancel;
    }, [loadRecords]),
  );
  const save = async () => {
    if (id && recordState !== 'ready') {
      show(recordState === 'missing' ? '该记录已不存在' : '记录仍在加载，请稍后再试', 'error');
      return;
    }
    if (
      (kind === 'allergy' && !values.allergenName.trim()) ||
      (kind === 'condition' && !values.conditionName.trim()) ||
      (kind === 'restriction' && !values.restrictionName.trim())
    ) {
      show('请填写记录名称', 'error');
      return;
    }
    if (
      kind === 'measurement' &&
      ![
        'heightCm',
        'weightKg',
        'bodyFatPercentage',
        'waistCm',
        'systolicBp',
        'diastolicBp',
        'restingHeartRate',
      ].some(key => values[key].trim())
    ) {
      show('请至少填写一个身体指标', 'error');
      return;
    }
    if (kind === 'goal' && values.targetWeightKg && !isWeight(values.targetWeightKg)) {
      show('目标体重应为 10.0–500.0 kg，最多一位小数', 'error');
      return;
    }
    if (
      kind === 'measurement' &&
      values.bodyFatPercentage &&
      normalizePercentageInput(values.bodyFatPercentage) == null
    ) {
      show(PERCENTAGE_VALIDATION_MESSAGE, 'error');
      return;
    }
    if (
      kind === 'goal' &&
      values.targetBodyFatPercentage &&
      normalizePercentageInput(values.targetBodyFatPercentage) == null
    ) {
      show(PERCENTAGE_VALIDATION_MESSAGE, 'error');
      return;
    }
    setSaving(true);
    try {
      if (kind === 'measurement') {
        const payload = {
          measuredAt: values.measuredAt || undefined,
          heightCm: asNumber(values.heightCm),
          weightKg: asNumber(values.weightKg),
          bodyFatPercentage: asNumber(values.bodyFatPercentage),
          waistCm: asNumber(values.waistCm),
          systolicBp: asNumber(values.systolicBp),
          diastolicBp: asNumber(values.diastolicBp),
          restingHeartRate: asNumber(values.restingHeartRate),
          source: 'manual' as const,
          notes: values.notes.trim() || undefined,
        };
        const saved = id
          ? await healthApi.bodyMeasurements.update(id, payload)
          : await healthApi.bodyMeasurements.create(payload);
        upsertHealthRecord('measurements', saved);
      }
      if (kind === 'goal') {
        const payload = {
          goalType: values.goalType as HealthGoal['goalType'],
          targetWeightKg: asNumber(values.targetWeightKg),
          targetBodyFatPercentage: asNumber(values.targetBodyFatPercentage),
          priority: asNumber(values.priority),
          status: values.status as HealthGoal['status'],
          startedOn: values.startedOn || undefined,
          targetDate: values.targetDate || undefined,
          notes: values.notes.trim() || undefined,
        };
        const saved = id
          ? await healthApi.healthGoals.update(id, payload)
          : await healthApi.healthGoals.create(payload);
        upsertHealthRecord('goals', saved);
      }
      if (kind === 'allergy') {
        const payload = {
          allergenCode: current && 'allergenCode' in current ? current.allergenCode : customCode(),
          allergenName: values.allergenName.trim(),
          severity: values.severity as NonNullable<Allergy['severity']>,
          diagnosisStatus: values.diagnosisStatus as Allergy['diagnosisStatus'],
          recordedOn: values.recordedOn || undefined,
          active: true,
          notes: values.notes.trim() || undefined,
        };
        const saved = id
          ? await healthApi.allergies.update(id, payload)
          : await healthApi.allergies.create(payload);
        upsertHealthRecord('allergies', saved);
      }
      if (kind === 'condition') {
        const payload = {
          conditionCode:
            current && 'conditionCode' in current ? current.conditionCode : customCode(),
          conditionName: values.conditionName.trim(),
          status: values.status as MedicalCondition['status'],
          diagnosedOn: values.diagnosedOn || undefined,
          resolvedOn: values.resolvedOn || undefined,
          source: 'self_reported' as const,
          notes: values.notes.trim() || undefined,
        };
        const saved = id
          ? await healthApi.medicalConditions.update(id, payload)
          : await healthApi.medicalConditions.create(payload);
        upsertHealthRecord('conditions', saved);
      }
      if (kind === 'restriction') {
        const payload = {
          restrictionCode:
            current && 'restrictionCode' in current ? current.restrictionCode : customCode(),
          restrictionName: values.restrictionName.trim(),
          category: values.category as DietaryRestriction['category'],
          source: 'self_reported' as const,
          active: true,
          startsOn: values.startsOn || undefined,
          endsOn: values.endsOn || undefined,
          notes: values.notes.trim() || undefined,
        };
        const saved = id
          ? await healthApi.dietaryRestrictions.update(id, payload)
          : await healthApi.dietaryRestrictions.create(payload);
        upsertHealthRecord('restrictions', saved);
      }
      show(`${kindTitle[kind]}已保存`, 'success');
      navigation.goBack();
    } catch (error) {
      show(getErrorMessage(error), 'error');
    } finally {
      setSaving(false);
    }
  };
  const deleteSummary = current ? getHealthRecordDeleteSummary(kind, current) : null;
  const remove = async () => {
    if (!id || !current) return;
    try {
      if (kind === 'measurement') {
        await healthApi.bodyMeasurements.remove(id);
        removeHealthRecord('measurements', id);
      }
      if (kind === 'goal') {
        await healthApi.healthGoals.remove(id);
        removeHealthRecord('goals', id);
      }
      if (kind === 'allergy') {
        await healthApi.allergies.remove(id);
        removeHealthRecord('allergies', id);
      }
      if (kind === 'condition') {
        await healthApi.medicalConditions.remove(id);
        removeHealthRecord('conditions', id);
      }
      if (kind === 'restriction') {
        await healthApi.dietaryRestrictions.remove(id);
        removeHealthRecord('restrictions', id);
      }
      setDeleteSheetVisible(false);
      show(`${kindTitle[kind]}已删除`, 'success');
      navigation.goBack();
    } catch (error) {
      show(getErrorMessage(error), 'error');
      throw error;
    }
  };
  const openItem = useCallback(
    (itemId: string) => {
      navigation.push('HealthRecordForm', {
        kind,
        id: itemId,
      });
    },
    [kind, navigation],
  );
  const keyExtractor = useCallback(
    (item: (typeof records)[number]) => getHealthRecordId(kind, item),
    [kind],
  );
  const renderRecord = useCallback(
    ({ item }: { item: (typeof records)[number] }) => {
      const itemId = getHealthRecordId(kind, item);
      const presentation = recordPresentation(kind, item);
      return (
        <PerfRegion name={`RecordItem:${itemId}`}>
          <GlassCard elevated={false} variant="soft" style={styles.recordListCard}>
            <RecordRow {...presentation} onPress={() => openItem(itemId)} />
          </GlassCard>
        </PerfRegion>
      );
    },
    [kind, openItem],
  );
  const allowPercentageClear =
    !id ||
    (recordState === 'ready' &&
      (kind === 'measurement'
        ? (current as BodyMeasurement | undefined)?.bodyFatPercentage == null
        : kind === 'goal'
        ? (current as HealthGoal | undefined)?.targetBodyFatPercentage == null
        : true));
  const fields =
    kind === 'measurement' ? (
      <>
        <DateField
          label="测量时间"
          mode="datetime"
          value={values.measuredAt}
          onChange={set('measuredAt')}
        />
        <Field label="体重 (kg)" value={values.weightKg} onChange={set('weightKg')} numeric />
        <PercentageSliderField
          allowClear={allowPercentageClear}
          label="体脂率"
          value={values.bodyFatPercentage}
          onChange={set('bodyFatPercentage')}
        />
        <Field label="腰围 (cm)" value={values.waistCm} onChange={set('waistCm')} numeric />
        <Field label="本次身高 (cm)" value={values.heightCm} onChange={set('heightCm')} numeric />
        <Field
          label="收缩压 (mmHg)"
          value={values.systolicBp}
          onChange={set('systolicBp')}
          numeric
        />
        <Field
          label="舒张压 (mmHg)"
          value={values.diastolicBp}
          onChange={set('diastolicBp')}
          numeric
        />
        <Field
          label="静息心率 (bpm)"
          value={values.restingHeartRate}
          onChange={set('restingHeartRate')}
          numeric
        />
        <Field label="备注" value={values.notes} onChange={set('notes')} multiline />
      </>
    ) : kind === 'goal' ? (
      <>
        <Choices
          label="目标方向"
          value={values.goalType}
          onChange={set('goalType')}
          values={[
            ['weight_loss', '减重'],
            ['muscle_gain', '增肌'],
            ['maintain', '保持'],
            ['health_improve', '改善健康'],
          ]}
        />
        <WeightWheelField
          label="目标体重 (kg)"
          value={values.targetWeightKg}
          onChange={set('targetWeightKg')}
        />
        <PercentageSliderField
          allowClear={allowPercentageClear}
          label="目标体脂率"
          value={values.targetBodyFatPercentage}
          onChange={set('targetBodyFatPercentage')}
        />
        <PriorityRating value={values.priority} onChange={set('priority')} />
        <DateField label="开始日期" value={values.startedOn} onChange={set('startedOn')} />
        <DateField
          label="目标日期"
          optional
          value={values.targetDate}
          onChange={set('targetDate')}
        />
        <Field label="备注" value={values.notes} onChange={set('notes')} multiline />
      </>
    ) : kind === 'allergy' ? (
      <>
        <Field
          label="过敏原名称"
          value={values.allergenName}
          onChange={set('allergenName')}
          placeholder="例如：花生"
        />
        <Choices
          label="严重程度"
          value={values.severity}
          onChange={set('severity')}
          values={[
            ['mild', '轻微'],
            ['moderate', '中等'],
            ['severe', '严重'],
            ['life_threatening', '危及生命'],
          ]}
        />
        <Choices
          label="确认状态"
          value={values.diagnosisStatus}
          onChange={set('diagnosisStatus')}
          values={[
            ['self_reported', '自行记录'],
            ['suspected', '疑似'],
            ['confirmed', '已确认'],
          ]}
        />
        <DateField
          label="记录日期"
          optional
          value={values.recordedOn}
          onChange={set('recordedOn')}
        />
        <Field label="备注" value={values.notes} onChange={set('notes')} multiline />
      </>
    ) : kind === 'condition' ? (
      <>
        <Field label="疾病名称" value={values.conditionName} onChange={set('conditionName')} />
        <Choices
          label="当前状态"
          value={values.status}
          onChange={set('status')}
          values={[
            ['active', '进行中'],
            ['remission', '缓解'],
            ['resolved', '已解决'],
          ]}
        />
        <DateField
          label="诊断日期"
          optional
          value={values.diagnosedOn}
          onChange={set('diagnosedOn')}
        />
        <DateField
          label="结束日期"
          optional
          value={values.resolvedOn}
          onChange={set('resolvedOn')}
        />
        <Field label="备注" value={values.notes} onChange={set('notes')} multiline />
      </>
    ) : (
      <>
        <Field
          label="限制名称"
          value={values.restrictionName}
          onChange={set('restrictionName')}
          placeholder="例如：不吃牛肉"
        />
        <Choices
          label="限制类别"
          value={values.category}
          onChange={set('category')}
          values={[
            ['medical', '医疗'],
            ['religious', '宗教'],
            ['lifestyle', '生活方式'],
            ['preference', '个人偏好'],
          ]}
        />
        <DateField label="生效日期" optional value={values.startsOn} onChange={set('startsOn')} />
        <DateField label="结束日期" optional value={values.endsOn} onChange={set('endsOn')} />
        <Field label="备注" value={values.notes} onChange={set('notes')} multiline />
      </>
    );
  if (!id && !route.params.create)
    return (
      <AppScreen
        scroll={false}
        contentStyle={styles.listScreen}
        header={
          <ScreenHeader
            title={kindTitle[kind]}
            subtitle="查看、修改或添加健康记录"
            onBack={() => navigation.goBack()}
          />
        }
      >
        <FlatList
          data={records}
          contentContainerStyle={styles.listContent}
          keyExtractor={keyExtractor}
          renderItem={renderRecord}
          removeClippedSubviews={Platform.OS === 'android'}
          initialNumToRender={8}
          windowSize={7}
          maxToRenderPerBatch={10}
          ListHeaderComponent={<SectionTitle title="已有记录" />}
          ListEmptyComponent={
            <EmptyState title="还没有记录" description="从第一条开始，逐步完善健康档案。" />
          }
          ListFooterComponent={
            <AppButton
              label={`添加${kindTitle[kind]}`}
              onPress={() =>
                navigation.replace('HealthRecordForm', {
                  kind,
                  create: true,
                })
              }
            />
          }
          showsVerticalScrollIndicator={false}
        />
      </AppScreen>
    );
  return (
    <AppScreen
      header={
        <ScreenHeader
          title={id ? `编辑${kindTitle[kind]}` : `添加${kindTitle[kind]}`}
          subtitle={id ? '修改后会同步更新健康档案' : '按需填写，之后也可随时编辑'}
          onBack={() => navigation.goBack()}
        />
      }
    >
      <GlassCard elevated={false} variant="soft" style={styles.formCard}>
        {fields}
        {id && recordState === 'loading' ? <Text style={styles.loading}>正在读取记录…</Text> : null}
        <AppButton
          disabled={Boolean(id && recordState !== 'ready')}
          label={id ? '保存修改' : `添加${kindTitle[kind]}`}
          loading={saving}
          onPress={save}
        />
        {id ? (
          <Pressable
            accessibilityRole="button"
            disabled={recordState !== 'ready' || !current}
            onPress={() => setDeleteSheetVisible(true)}
            style={[styles.delete, (recordState !== 'ready' || !current) && styles.deleteDisabled]}
          >
            <Trash2 color={colors.red} size={17} />
            <Text style={styles.deleteText}>删除这条记录</Text>
          </Pressable>
        ) : null}
      </GlassCard>
      {deleteSummary ? (
        <DestructiveConfirmSheet
          detail={deleteSummary.detail}
          onCancel={() => setDeleteSheetVisible(false)}
          onConfirm={remove}
          summary={deleteSummary.summary}
          title={deleteSummary.title}
          visible={deleteSheetVisible}
        />
      ) : null}
    </AppScreen>
  );
}
const styles = StyleSheet.create({
  loading: {
    color: colors.muted,
    fontFamily: fonts.body,
    textAlign: 'center',
    fontSize: 12,
  },
  recordRow: {
    minHeight: 76,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingVertical: spacing.md,
  },
  recordRowCopy: {
    flex: 1,
    minWidth: 0,
  },
  rowTitle: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontSize: 14,
    fontWeight: '800',
  },
  rowDetail: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 11,
    marginTop: 3,
  },
  recordBadges: {
    maxWidth: '45%',
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'flex-end',
    gap: 5,
  },
  recordBadge: {
    maxWidth: '100%',
    borderRadius: radii.pill,
    backgroundColor: colors.blueSoft,
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  recordBadgeText: {
    color: colors.blue,
    fontFamily: fonts.body,
    fontSize: 10,
    fontWeight: '800',
  },
  recordBadgeAmber: {
    backgroundColor: '#FFF4E4',
  },
  recordBadgeAmberText: {
    color: '#B76B00',
  },
  recordBadgeRed: {
    backgroundColor: '#FFF0F0',
  },
  recordBadgeRedText: {
    color: colors.red,
  },
  recordBadgeGreen: {
    backgroundColor: '#EAF9EF',
  },
  recordBadgeGreenText: {
    color: colors.green,
  },
  recordBadgePlain: {
    backgroundColor: '#F1F5F9',
  },
  recordBadgePlainText: {
    color: colors.muted,
  },
  formCard: {
    gap: spacing.md,
  },
  listScreen: {
    flex: 1,
  },
  listContent: {
    paddingHorizontal: spacing.lg,
    paddingBottom: 104,
    gap: spacing.sm,
  },
  recordListCard: {
    paddingVertical: 0,
  },
  field: {
    gap: 7,
  },
  fieldLabel: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontSize: 13,
    fontWeight: '700',
  },
  fieldHint: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 11,
    lineHeight: 16,
  },
  selectValueCard: {
    minHeight: 54,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderWidth: 1,
    borderColor: '#DCE7F1',
    borderRadius: radii.md,
    backgroundColor: 'rgba(255,255,255,0.78)',
    paddingHorizontal: spacing.md,
  },
  selectValue: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontSize: 15,
    fontWeight: '800',
  },
  ratingSheet: {
    alignItems: 'center',
    gap: spacing.md,
    paddingVertical: spacing.md,
  },
  sheetMetric: {
    color: colors.blue,
    fontFamily: fonts.display,
    fontSize: 28,
    fontWeight: '800',
  },
  stars: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    minHeight: 36,
  },
  starHitArea: {
    width: 31,
    height: 34,
  },
  starFill: {
    position: 'absolute',
    top: 0,
    left: 0,
    height: 34,
    overflow: 'hidden',
  },
  starHalfLeft: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    width: '50%',
  },
  starHalfRight: {
    position: 'absolute',
    right: 0,
    top: 0,
    bottom: 0,
    width: '50%',
  },
  multiline: {
    minHeight: 88,
    textAlignVertical: 'top',
    paddingTop: spacing.md,
  },
  delete: {
    alignSelf: 'center',
    alignItems: 'center',
    flexDirection: 'row',
    gap: 6,
    padding: spacing.sm,
  },
  deleteDisabled: {
    opacity: 0.48,
  },
  deleteText: {
    color: colors.red,
    fontFamily: fonts.body,
    fontSize: 13,
    fontWeight: '800',
  },
});
