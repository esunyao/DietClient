export interface ApiEnvelope<T> {
  code: number;
  message: string;
  data: T | null;
  traceId?: string | null;
  timestamp?: number;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export interface User {
  userId: string;
  username: string;
  email: string;
  nickname: string;
  avatarUrl: string;
  status: 'active' | 'disabled' | string;
  createdAt: string;
  updatedAt: string;
}

export type Gender = 'male' | 'female' | 'other';
export type ActivityLevel = 'sedentary' | 'light' | 'moderate' | 'active' | 'very_active';
export type HealthGoal = 'weight_loss' | 'muscle_gain' | 'maintain' | 'health_improve';

export interface UserProfile {
  profileId: string;
  userId: string;
  age: number | null;
  gender: Gender | null;
  heightCm: number | null;
  weightKg: number | null;
  bmi: number | null;
  activityLevel: ActivityLevel | null;
  healthGoal: HealthGoal | null;
  allergies: string[];
  dietaryRestrictions: string[];
  medicalConditions: string[];
  dailyWaterMl: number;
  preferredCuisine: string[];
  createdAt: string;
  updatedAt: string;
}

export interface LoginPayload {
  username: string;
  password: string;
}

export interface RegisterPayload extends LoginPayload {
  email: string;
  nickname: string;
}

export interface ProfileUpdatePayload {
  age?: number;
  gender?: Gender;
  heightCm?: number;
  weightKg?: number;
  activityLevel?: ActivityLevel;
  healthGoal?: HealthGoal;
  allergies?: string[];
  dietaryRestrictions?: string[];
  medicalConditions?: string[];
  dailyWaterMl?: number;
  preferredCuisine?: string[];
}

/** 对象存储预签名上传与确认接口的数据结构。 */
export interface AvatarPresignPayload {
  fileName: string;
  contentType: 'image/jpeg' | 'image/png' | 'image/webp';
}

export interface AvatarPresignResult {
  uploadUrl: string;
  objectKey: string;
  expiresIn: number;
}

export interface AvatarConfirmResult {
  avatarUrl: string;
}
