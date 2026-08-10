export type AuthStackParamList = {
  Login: { registeredUsername?: string } | undefined;
  Register: undefined;
};

export type HomeStackParamList = {
  HomeMain: undefined;
  ScoreDetail: undefined;
};

export type ProfileStackParamList = {
  ProfileMain: undefined;
  EditProfile: undefined;
};

export type AppTabParamList = {
  HomeTab: undefined;
  RecognitionTab: undefined;
  MealTab: undefined;
  TrendsTab: undefined;
  ReportsTab: undefined;
  ProfileTab: undefined;
};
