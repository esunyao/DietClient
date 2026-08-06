import React, { useEffect } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { NavigationContainer, DefaultTheme } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { BarChart3, Camera, FileText, Home, Sparkles, UserRound } from 'lucide-react-native';

import { LoginScreen, RegisterScreen } from '../features/auth/screens/AuthScreens';
import { useSessionStore } from '../features/auth/store/sessionStore';
import { HomeScreen, MealPlanScreen, RecognitionScreen, ReportsScreen, ScoreDetailScreen, TrendsScreen } from '../features/diet/screens/StaticScreens';
import { ChangePasswordScreen, EditProfileScreen, ProfileScreen } from '../features/profile/screens/ProfileScreens';
import { colors, fonts } from '../shared/theme/tokens';
import type { AppTabParamList, AuthStackParamList, HomeStackParamList, ProfileStackParamList } from './types';

const AuthStack = createNativeStackNavigator<AuthStackParamList>();
const HomeStack = createNativeStackNavigator<HomeStackParamList>();
const ProfileStack = createNativeStackNavigator<ProfileStackParamList>();
const Tab = createBottomTabNavigator<AppTabParamList>();

const navigationTheme = {
  ...DefaultTheme,
  colors: { ...DefaultTheme.colors, background: colors.canvas, card: colors.surface, text: colors.ink, border: colors.line, primary: colors.blue },
};

function AuthNavigator() {
  return (
    <AuthStack.Navigator screenOptions={{ headerShown: false, animation: 'fade' }}>
      <AuthStack.Screen name="Login" component={LoginScreen} />
      <AuthStack.Screen name="Register" component={RegisterScreen} />
    </AuthStack.Navigator>
  );
}

function HomeNavigator() {
  return (
    <HomeStack.Navigator screenOptions={{ headerShown: false, animation: 'slide_from_right' }}>
      <HomeStack.Screen name="HomeMain" component={HomeScreen} />
      <HomeStack.Screen name="ScoreDetail" component={ScoreDetailScreen} />
    </HomeStack.Navigator>
  );
}

function ProfileNavigator() {
  return (
    <ProfileStack.Navigator screenOptions={{ headerShown: false, animation: 'slide_from_right' }}>
      <ProfileStack.Screen name="ProfileMain" component={ProfileScreen} />
      <ProfileStack.Screen name="EditProfile" component={EditProfileScreen} />
      <ProfileStack.Screen name="ChangePassword" component={ChangePasswordScreen} />
    </ProfileStack.Navigator>
  );
}

function tabIcon(name: keyof AppTabParamList, color: string, size: number) {
  const iconProps = { color, size, strokeWidth: 2.3 };
  switch (name) {
    case 'HomeTab': return <Home {...iconProps} />;
    case 'RecognitionTab': return <Camera {...iconProps} />;
    case 'MealTab': return <Sparkles {...iconProps} />;
    case 'TrendsTab': return <BarChart3 {...iconProps} />;
    case 'ReportsTab': return <FileText {...iconProps} />;
    case 'ProfileTab': return <UserRound {...iconProps} />;
  }
}

function MainNavigator() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarActiveTintColor: colors.blue,
        tabBarInactiveTintColor: '#7A8BA0',
        tabBarHideOnKeyboard: true,
        tabBarIcon: ({ color, size }) => tabIcon(route.name, color, size),
        tabBarLabelStyle: styles.tabLabel,
        tabBarStyle: styles.tabBar,
        tabBarItemStyle: styles.tabItem,
      })}
    >
      <Tab.Screen name="HomeTab" component={HomeNavigator} options={{ title: '首页' }} />
      <Tab.Screen name="RecognitionTab" component={RecognitionScreen} options={{ title: '识别' }} />
      <Tab.Screen name="MealTab" component={MealPlanScreen} options={{ title: '配餐' }} />
      <Tab.Screen name="TrendsTab" component={TrendsScreen} options={{ title: '趋势' }} />
      <Tab.Screen name="ReportsTab" component={ReportsScreen} options={{ title: '报告' }} />
      <Tab.Screen name="ProfileTab" component={ProfileNavigator} options={{ title: '我的' }} />
    </Tab.Navigator>
  );
}

function SessionSplash() {
  return <View style={styles.splash}><View style={styles.splashDot} /><Text style={styles.splashText}>正在准备健康档案…</Text></View>;
}

/** 根路由通过会话状态切换认证区与主应用，无需在每个页面重复做登录判断。 */
export function AppNavigator() {
  const status = useSessionStore(state => state.status);
  const hydrate = useSessionStore(state => state.hydrate);

  useEffect(() => {
    hydrate().catch(() => undefined);
  }, [hydrate]);

  if (status === 'restoring') {
    return <SessionSplash />;
  }

  return <NavigationContainer theme={navigationTheme}>{status === 'signedIn' ? <MainNavigator /> : <AuthNavigator />}</NavigationContainer>;
}

const styles = StyleSheet.create({
  splash: { flex: 1, backgroundColor: colors.canvas, alignItems: 'center', justifyContent: 'center', gap: 12 },
  splashDot: { width: 14, height: 14, borderRadius: 7, backgroundColor: colors.green, boxShadow: '0 0 15px rgba(52, 199, 89, 0.50)' },
  splashText: { color: colors.muted, fontFamily: fonts.body, fontSize: 13, fontWeight: '700' },
  tabBar: { position: 'absolute', left: 12, right: 12, bottom: 12, height: 66, borderRadius: 24, borderTopWidth: 0, backgroundColor: 'rgba(255,255,255,0.96)', paddingTop: 7, paddingBottom: 5, boxShadow: '0 8px 22px rgba(58, 90, 120, 0.16)' },
  tabItem: { borderRadius: 18 },
  tabLabel: { fontFamily: fonts.body, fontSize: 10, fontWeight: '700', marginTop: -3 },
});
