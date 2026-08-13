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

export type AppTabParamList = {
  HomeTab: undefined;
  RecognitionTab: undefined;
  MealTab: undefined;
  TrendsTab: undefined;
  ReportsTab: undefined;
  ProfileTab: undefined;
};
