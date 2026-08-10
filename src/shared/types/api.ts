/** Orion 统一响应包装。 */
export interface ApiEnvelope<T> {
  code: number;
  message: string;
  data: T | null;
  traceId?: string | null;
  timestamp?: number | string;
}

/** Authentik OIDC Token Endpoint 返回值。Token 只在内存中使用。 */
export interface OidcTokenSet {
  accessToken: string;
  refreshToken: string | null;
  tokenType: string;
  expiresIn: number;
  idToken?: string;
  obtainedAt: number;
}

export interface User {
  userId: string;
  username: string;
  email: string | null;
  emailVerified: boolean;
  displayName: string;
  avatarUrl: string | null;
  businessStatus: 'active' | 'suspended' | 'deactivated';
  locale: string;
  timezone: string;
  lastSeenAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export type Gender = 'male' | 'female' | 'other' | 'unknown';
export type ActivityLevel = 'sedentary' | 'light' | 'moderate' | 'active' | 'very_active';
export type HealthGoalType = 'weight_loss' | 'muscle_gain' | 'maintain' | 'health_improve';
export type HealthGoalStatus = 'planned' | 'active' | 'achieved' | 'cancelled';
export type MeasurementSource = 'manual' | 'device' | 'import' | 'clinical';
export type AllergySeverity = 'mild' | 'moderate' | 'severe' | 'life_threatening';
export type DiagnosisStatus = 'self_reported' | 'suspected' | 'confirmed';
export type ConditionStatus = 'active' | 'remission' | 'resolved';
export type ConditionSource = 'self_reported' | 'clinical' | 'imported';
export type RestrictionCategory = 'medical' | 'religious' | 'lifestyle' | 'preference';
export type RestrictionSource = 'self_reported' | 'clinician' | 'system';
export type ObservationInterpretation = 'low' | 'normal' | 'high' | 'critical' | 'unknown';
export type ObservationSource = 'self_reported' | 'clinical' | 'device' | 'imported';
export type ConsentSource = 'mobile' | 'web' | 'admin' | 'imported';

export interface UserProfile {
  userId: string;
  birthDate: string | null;
  gender: Gender | null;
  heightCm: number | null;
  activityLevel: ActivityLevel | null;
  dailyWaterTargetMl: number;
  profileCompletedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface UserProfileUpdatePayload {
  birthDate?: string | null;
  gender?: Gender | null;
  heightCm?: number | null;
  activityLevel?: ActivityLevel | null;
  dailyWaterTargetMl?: number | null;
}

export interface BodyMeasurement {
  measurementId: string;
  userId: string;
  measuredAt: string;
  heightCm: number | null;
  weightKg: number | null;
  bodyFatPercentage: number | null;
  waistCm: number | null;
  systolicBp: number | null;
  diastolicBp: number | null;
  restingHeartRate: number | null;
  source: MeasurementSource;
  sourceReference: string | null;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface BodyMeasurementRequest {
  measuredAt?: string;
  heightCm?: number;
  weightKg?: number;
  bodyFatPercentage?: number;
  waistCm?: number;
  systolicBp?: number;
  diastolicBp?: number;
  restingHeartRate?: number;
  source?: MeasurementSource;
  sourceReference?: string;
  notes?: string;
}

export interface HealthGoal {
  goalId: string;
  userId: string;
  goalType: HealthGoalType;
  targetWeightKg: number | null;
  targetBodyFatPercentage: number | null;
  priority: number;
  status: HealthGoalStatus;
  startedOn: string;
  targetDate: string | null;
  completedAt: string | null;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface HealthGoalRequest {
  goalType: HealthGoalType;
  targetWeightKg?: number;
  targetBodyFatPercentage?: number;
  priority?: number;
  status?: HealthGoalStatus;
  startedOn?: string;
  targetDate?: string;
  notes?: string;
}

export interface Allergy {
  allergyId: string;
  userId: string;
  allergenCode: string;
  allergenName: string;
  severity: AllergySeverity | null;
  reactionDescription: string | null;
  diagnosisStatus: DiagnosisStatus;
  recordedOn: string | null;
  active: boolean;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface AllergyRequest {
  allergenCode: string;
  allergenName: string;
  severity?: AllergySeverity;
  reactionDescription?: string;
  diagnosisStatus?: DiagnosisStatus;
  recordedOn?: string;
  active?: boolean;
  notes?: string;
}

export interface MedicalCondition {
  conditionId: string;
  userId: string;
  conditionCode: string;
  conditionName: string;
  status: ConditionStatus;
  diagnosedOn: string | null;
  resolvedOn: string | null;
  source: ConditionSource;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface MedicalConditionRequest {
  conditionCode: string;
  conditionName: string;
  status?: ConditionStatus;
  diagnosedOn?: string;
  resolvedOn?: string;
  source?: ConditionSource;
  notes?: string;
}

export interface DietaryRestriction {
  restrictionId: string;
  userId: string;
  restrictionCode: string;
  restrictionName: string;
  category: RestrictionCategory;
  source: RestrictionSource;
  active: boolean;
  startsOn: string | null;
  endsOn: string | null;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface DietaryRestrictionRequest {
  restrictionCode: string;
  restrictionName: string;
  category: RestrictionCategory;
  source?: RestrictionSource;
  active?: boolean;
  startsOn?: string;
  endsOn?: string;
  notes?: string;
}

export interface CuisinePreference {
  userId: string;
  cuisineCode: string;
  cuisineName: string;
  preferenceScore: number;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface CuisinePreferenceRequest {
  cuisineCode: string;
  cuisineName: string;
  preferenceScore?: number;
  notes?: string;
}

export interface ClinicalObservation {
  observationId: string;
  userId: string;
  observationCode: string;
  observationName: string;
  valueNumeric: number | null;
  valueText: string | null;
  unit: string | null;
  referenceLow: number | null;
  referenceHigh: number | null;
  interpretation: ObservationInterpretation;
  observedAt: string;
  source: ObservationSource;
  reportObjectKey: string | null;
  metadata: string;
  createdAt: string;
}

export interface ClinicalObservationRequest {
  observationCode: string;
  observationName: string;
  valueNumeric?: number;
  valueText?: string;
  unit?: string;
  referenceLow?: number;
  referenceHigh?: number;
  interpretation?: ObservationInterpretation;
  observedAt?: string;
  source?: ObservationSource;
  reportObjectKey?: string;
  metadata?: string;
}

export interface UserConsent {
  consentId: string;
  userId: string;
  consentType: string;
  policyVersion: string;
  granted: boolean;
  recordedAt: string;
  source: ConsentSource;
  clientIp: string | null;
  userAgent: string | null;
  createdAt: string;
}

export interface UserConsentRequest {
  consentType: string;
  policyVersion: string;
  granted?: boolean;
  source?: ConsentSource;
}

export interface AvatarPresignPayload {
  fileName: string;
  contentType: 'image/jpeg' | 'image/png' | 'image/webp' | 'image/gif';
}

export interface AvatarPresignResult {
  uploadUrl: string;
  objectKey: string;
  expiresIn: number | string;
}

export interface AvatarConfirmResult {
  avatarUrl: string;
}
