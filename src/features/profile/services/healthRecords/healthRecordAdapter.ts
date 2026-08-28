import { healthApi } from '../../api/healthApi';
import type {
  Allergy,
  BodyMeasurement,
  DietaryRestriction,
  HealthGoal,
  MedicalCondition,
} from '../../api/profileTypes';

export type HealthRecordKind = 'measurement' | 'goal' | 'allergy' | 'condition' | 'restriction';

export type HealthRecord =
  | BodyMeasurement
  | HealthGoal
  | Allergy
  | MedicalCondition
  | DietaryRestriction;

/**
 * 集中处理五类健康记录的标识字段。后端字段名不同，但页面和缓存不应使用动态索引猜测。
 */
export function getHealthRecordId(kind: HealthRecordKind, record: HealthRecord): string {
  switch (kind) {
    case 'measurement':
      return (record as BodyMeasurement).measurementId;
    case 'goal':
      return (record as HealthGoal).goalId;
    case 'allergy':
      return (record as Allergy).allergyId;
    case 'condition':
      return (record as MedicalCondition).conditionId;
    case 'restriction':
      return (record as DietaryRestriction).restrictionId;
  }
}

/** 页面只声明记录类别；具体 endpoint 的选择保留在 profile 领域适配层。 */
export async function listHealthRecords(kind: HealthRecordKind): Promise<HealthRecord[]> {
  switch (kind) {
    case 'measurement':
      return healthApi.bodyMeasurements.list();
    case 'goal':
      return healthApi.healthGoals.list();
    case 'allergy':
      return healthApi.allergies.list();
    case 'condition':
      return healthApi.medicalConditions.list();
    case 'restriction':
      return healthApi.dietaryRestrictions.list();
  }
}
