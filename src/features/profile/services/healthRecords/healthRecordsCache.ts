import type {
  Allergy,
  BodyMeasurement,
  DietaryRestriction,
  HealthGoal,
  MedicalCondition,
} from '../../api/profileTypes';
import { healthApi } from '../../api/healthApi';
import { getHealthRecordId, type HealthRecordKind } from './healthRecordAdapter';

export type HealthRecordsSnapshot = {
  measurements: BodyMeasurement[];
  goals: HealthGoal[];
  allergies: Allergy[];
  conditions: MedicalCondition[];
  restrictions: DietaryRestriction[];
};

let cachedSnapshot: HealthRecordsSnapshot | null = null;
let pendingRequest: Promise<HealthRecordsSnapshot> | null = null;

export function getCachedHealthRecords(): HealthRecordsSnapshot | null {
  return cachedSnapshot;
}

export async function getHealthRecords(force = false): Promise<HealthRecordsSnapshot> {
  if (!force && cachedSnapshot) {
    return cachedSnapshot;
  }
  if (!force && pendingRequest) {
    return pendingRequest;
  }

  const request = Promise.all([
    healthApi.bodyMeasurements.list(),
    healthApi.healthGoals.list(),
    healthApi.allergies.list(),
    healthApi.medicalConditions.list(),
    healthApi.dietaryRestrictions.list(),
  ]).then(([measurements, goals, allergies, conditions, restrictions]) => {
    const snapshot = { measurements, goals, allergies, conditions, restrictions };
    cachedSnapshot = snapshot;
    return snapshot;
  });

  pendingRequest = request;
  try {
    return await request;
  } finally {
    if (pendingRequest === request) {
      pendingRequest = null;
    }
  }
}

export function invalidateHealthRecords(): void {
  cachedSnapshot = null;
}

type HealthRecordCacheKind = keyof HealthRecordsSnapshot;
type HealthRecordByKind = {
  measurements: BodyMeasurement;
  goals: HealthGoal;
  allergies: Allergy;
  conditions: MedicalCondition;
  restrictions: DietaryRestriction;
};

const adapterKind: Record<HealthRecordCacheKind, HealthRecordKind> = {
  measurements: 'measurement',
  goals: 'goal',
  allergies: 'allergy',
  conditions: 'condition',
  restrictions: 'restriction',
};

/** 将已由服务端确认的单条变更同步到摘要缓存，避免返回上一页时展示旧计数。 */
export function upsertHealthRecord<K extends HealthRecordCacheKind>(
  kind: K,
  record: HealthRecordByKind[K],
): void {
  if (!cachedSnapshot) return;
  const nextRecords = cachedSnapshot[kind] as HealthRecordByKind[K][];
  const identifier = getHealthRecordId(adapterKind[kind], record);
  const position = nextRecords.findIndex(
    item => getHealthRecordId(adapterKind[kind], item) === identifier,
  );
  const updated =
    position < 0
      ? [...nextRecords, record]
      : nextRecords.map((item, index) => (index === position ? record : item));
  cachedSnapshot = { ...cachedSnapshot, [kind]: updated } as HealthRecordsSnapshot;
}

export function removeHealthRecord<K extends HealthRecordCacheKind>(kind: K, id: string): void {
  if (!cachedSnapshot) return;
  const nextRecords = (cachedSnapshot[kind] as HealthRecordByKind[K][]).filter(
    item => getHealthRecordId(adapterKind[kind], item) !== id,
  );
  cachedSnapshot = { ...cachedSnapshot, [kind]: nextRecords } as HealthRecordsSnapshot;
}
