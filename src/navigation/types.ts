import type { NavigatorScreenParams } from '@react-navigation/native';

import type { Food, MealId } from '../features/diet/api/nutriTypes';

export type AuthStackParamList = {
  Login: { registeredUsername?: string; emailVerified?: boolean } | undefined;
  Register: undefined;
  VerifyEmail: { email: string; username?: string };
  EmailVerified: undefined;
};

export type HomeStackParamList = {
  HomeMain: undefined;
  ScoreDetail: undefined;
};

export type ProfileStackParamList = {
  ProfileMain: undefined;
  EditProfile: { onboarding?: boolean } | undefined;
  HealthRecords: { onboarding?: boolean } | undefined;
  HealthRecordForm: { kind: 'measurement' | 'goal' | 'allergy' | 'condition' | 'restriction'; id?: string; create?: boolean };
};

export type DietStackParamList = {
  MealEntry: { mealId?: MealId; createdFood?: Food } | undefined;
  MealHistory: undefined;
  MealDetail: { mealId: MealId };
  CustomFood: undefined;
};

export type AppTabParamList = {
  HomeTab: undefined;
  RecognitionTab: NavigatorScreenParams<DietStackParamList> | undefined;
  MealTab: undefined;
  TrendsTab: undefined;
  ReportsTab: undefined;
  ProfileTab: undefined;
};
