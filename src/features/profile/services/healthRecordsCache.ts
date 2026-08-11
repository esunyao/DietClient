import type {
  Allergy,
  BodyMeasurement,
  DietaryRestriction,
  HealthGoal,
  MedicalCondition,
} from '../../../shared/types/api';
import { healthApi } from '../api/healthApi';

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

export async function getHealthRecords(
  force = false,
): Promise<HealthRecordsSnapshot> {
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
