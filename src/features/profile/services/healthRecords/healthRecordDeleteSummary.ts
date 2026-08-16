import type { Allergy, BodyMeasurement, DietaryRestriction, HealthGoal, MedicalCondition } from '../../../../shared/types/api';

export type HealthRecordDeleteKind = 'measurement' | 'goal' | 'allergy' | 'condition' | 'restriction';
export type HealthRecordDeleteRecord = BodyMeasurement | HealthGoal | Allergy | MedicalCondition | DietaryRestriction;

const goalLabels: Record<HealthGoal['goalType'], string> = {
  weight_loss: '减重',
  muscle_gain: '增肌',
  maintain: '保持体重',
  health_improve: '改善健康',
};
const severityLabels: Record<NonNullable<Allergy['severity']>, string> = { mild: '轻微', moderate: '中等', severe: '严重', life_threatening: '危及生命' };
const conditionLabels: Record<MedicalCondition['status'], string> = { active: '进行中', remission: '缓解', resolved: '已解决' };
const restrictionLabels: Record<DietaryRestriction['category'], string> = { medical: '医疗', religious: '宗教', lifestyle: '生活方式', preference: '个人偏好' };

function date(value?: string | null): string {
  return value ? value.slice(0, 10) : '未填写日期';
}

export function getHealthRecordDeleteSummary(kind: HealthRecordDeleteKind, record: HealthRecordDeleteRecord): { title: string; summary: string; detail: string } {
  if (kind === 'measurement') {
    const item = record as BodyMeasurement;
    const metric = item.weightKg == null ? item.bodyFatPercentage == null ? '尚未填写关键指标' : `${item.bodyFatPercentage}% 体脂` : `${item.weightKg} kg`;
    return { title: '删除身体测量？', summary: `${date(item.measuredAt)} · ${metric}`, detail: '这次测量中的体重、体脂和围度等数据都会被移除。' };
  }
  if (kind === 'goal') {
    const item = record as HealthGoal;
    const target = item.targetWeightKg == null ? item.targetBodyFatPercentage == null ? '尚未设置目标数值' : `${item.targetBodyFatPercentage}% 体脂` : `${item.targetWeightKg} kg`;
    return { title: '删除健康目标？', summary: `${goalLabels[item.goalType]} · ${target}`, detail: '删除后，这个目标及其进度信息将从健康档案中移除。' };
  }
  if (kind === 'allergy') {
    const item = record as Allergy;
    return { title: '删除过敏记录？', summary: `${item.allergenName} · ${severityLabels[item.severity ?? 'mild']}`, detail: '删除后，这条过敏原和严重程度记录将无法恢复。' };
  }
  if (kind === 'condition') {
    const item = record as MedicalCondition;
    return { title: '删除疾病记录？', summary: `${item.conditionName} · ${conditionLabels[item.status]}`, detail: '删除后，这条疾病状态和诊断信息将无法恢复。' };
  }
  const item = record as DietaryRestriction;
  return { title: '删除饮食限制？', summary: `${item.restrictionName} · ${restrictionLabels[item.category]}`, detail: '删除后，这条饮食限制及其生效日期将无法恢复。' };
}
