import { apiClient, assertApiSuccess, unwrapApiResponse } from '../../../shared/api/client';
import type {
  Allergy,
  AllergyRequest,
  BodyMeasurement,
  BodyMeasurementRequest,
  ClinicalObservation,
  ClinicalObservationRequest,
  CuisinePreference,
  CuisinePreferenceRequest,
  DietaryRestriction,
  DietaryRestrictionRequest,
  HealthGoal,
  HealthGoalRequest,
  MedicalCondition,
  MedicalConditionRequest,
  UserConsent,
  UserConsentRequest,
} from './profileTypes';
import type { ApiEnvelope } from '../../../shared/api/types';

async function list<T>(path: string): Promise<T[]> {
  const response = await apiClient.get<ApiEnvelope<T[]>>(path);
  return unwrapApiResponse(response);
}

async function create<T, P>(path: string, payload: P): Promise<T> {
  const response = await apiClient.post<ApiEnvelope<T>>(path, payload);
  return unwrapApiResponse(response);
}

async function update<T, P>(path: string, id: string, payload: P): Promise<T> {
  const response = await apiClient.patch<ApiEnvelope<T>>(
    `${path}/${encodeURIComponent(id)}`,
    payload,
  );
  return unwrapApiResponse(response);
}

async function remove(path: string, id: string): Promise<void> {
  const response = await apiClient.delete<ApiEnvelope<unknown>>(
    `${path}/${encodeURIComponent(id)}`,
  );
  assertApiSuccess(response);
}

const bodyPath = 'v1/users/self/body-measurements';
const goalPath = 'v1/users/self/health-goals';
const allergyPath = 'v1/users/self/allergies';
const conditionPath = 'v1/users/self/medical-conditions';
const restrictionPath = 'v1/users/self/dietary-restrictions';

export const healthApi = {
  bodyMeasurements: {
    list: () => list<BodyMeasurement>(bodyPath),
    create: (payload: BodyMeasurementRequest) =>
      create<BodyMeasurement, BodyMeasurementRequest>(bodyPath, payload),
    update: (id: string, payload: BodyMeasurementRequest) =>
      update<BodyMeasurement, BodyMeasurementRequest>(bodyPath, id, payload),
    remove: (id: string) => remove(bodyPath, id),
  },
  healthGoals: {
    list: () => list<HealthGoal>(goalPath),
    create: (payload: HealthGoalRequest) =>
      create<HealthGoal, HealthGoalRequest>(goalPath, payload),
    update: (id: string, payload: HealthGoalRequest) =>
      update<HealthGoal, HealthGoalRequest>(goalPath, id, payload),
    remove: (id: string) => remove(goalPath, id),
  },
  allergies: {
    list: () => list<Allergy>(allergyPath),
    create: (payload: AllergyRequest) => create<Allergy, AllergyRequest>(allergyPath, payload),
    update: (id: string, payload: AllergyRequest) =>
      update<Allergy, AllergyRequest>(allergyPath, id, payload),
    remove: (id: string) => remove(allergyPath, id),
  },
  medicalConditions: {
    list: () => list<MedicalCondition>(conditionPath),
    create: (payload: MedicalConditionRequest) =>
      create<MedicalCondition, MedicalConditionRequest>(conditionPath, payload),
    update: (id: string, payload: MedicalConditionRequest) =>
      update<MedicalCondition, MedicalConditionRequest>(conditionPath, id, payload),
    remove: (id: string) => remove(conditionPath, id),
  },
  dietaryRestrictions: {
    list: () => list<DietaryRestriction>(restrictionPath),
    create: (payload: DietaryRestrictionRequest) =>
      create<DietaryRestriction, DietaryRestrictionRequest>(restrictionPath, payload),
    update: (id: string, payload: DietaryRestrictionRequest) =>
      update<DietaryRestriction, DietaryRestrictionRequest>(restrictionPath, id, payload),
    remove: (id: string) => remove(restrictionPath, id),
  },
  cuisinePreferences: {
    list: () => list<CuisinePreference>('v1/users/self/cuisine-preferences'),
    replace: async (preferences: CuisinePreferenceRequest[]): Promise<CuisinePreference[]> => {
      const response = await apiClient.put<ApiEnvelope<CuisinePreference[]>>(
        'v1/users/self/cuisine-preferences',
        { preferences },
      );
      return unwrapApiResponse(response);
    },
  },
  clinicalObservations: {
    list: () => list<ClinicalObservation>('v1/users/self/clinical-observations'),
    create: (payload: ClinicalObservationRequest) =>
      create<ClinicalObservation, ClinicalObservationRequest>(
        'v1/users/self/clinical-observations',
        payload,
      ),
  },
  consents: {
    list: () => list<UserConsent>('v1/users/self/consents'),
    create: (payload: UserConsentRequest) =>
      create<UserConsent, UserConsentRequest>('v1/users/self/consents', payload),
  },
};
