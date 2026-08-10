import React, { useEffect } from 'react';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';
import { NavigationContainer, DefaultTheme } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

// 认证相关页面
import {
  LoginScreen,
  RegisterScreen,
} from '../features/auth/screens/AuthScreens';
// 会话/登录状态 Store
import { useSessionStore } from '../features/auth/store/sessionStore';
// 饮食/主功能相关页面
import {
  HomeScreen,
  MealPlanScreen,
  RecognitionScreen,
  ReportsScreen,
  ScoreDetailScreen,
  TrendsScreen,
} from '../features/diet/screens/StaticScreens';
// 个人中心相关页面
import {
  EditProfileScreen,
  ProfileScreen,
} from '../features/profile/screens/ProfileScreens';
// 主题 Token
import { colors, fonts } from '../shared/theme/tokens';
// 自定义毛玻璃 TabBar
import { FrostedTabBar } from './components/FrostedTabBar';
// 路由类型定义
import type {
  AppTabParamList,
  AuthStackParamList,
  HomeStackParamList,
  ProfileStackParamList,
} from './types';

const AuthStack = createNativeStackNavigator<AuthStackParamList>();
const HomeStack = createNativeStackNavigator<HomeStackParamList>();
const ProfileStack = createNativeStackNavigator<ProfileStackParamList>();
const Tab = createBottomTabNavigator<AppTabParamList>();

/**
 * 底部 `Tab` 设定
 * */

// 全局导航主题
const navigationTheme = {
  ...DefaultTheme,
  colors: {
    ...DefaultTheme.colors,
    background: colors.canvas,
    card: colors.surface,
    text: colors.ink,
    border: colors.line,
    primary: colors.blue,
  },
};

// 认证模块 Stack
function AuthNavigator() {
  return (
    <AuthStack.Navigator
      screenOptions={{ headerShown: false, animation: 'fade' }}
    >
      <AuthStack.Screen name="Login" component={LoginScreen} />
      <AuthStack.Screen name="Register" component={RegisterScreen} />
    </AuthStack.Navigator>
  );
}

// 首页模块 Stack
function HomeNavigator() {
  return (
    <HomeStack.Navigator
      screenOptions={{ headerShown: false, animation: 'slide_from_right' }}
    >
      <HomeStack.Screen name="HomeMain" component={HomeScreen} />
      <HomeStack.Screen name="ScoreDetail" component={ScoreDetailScreen} />
    </HomeStack.Navigator>
  );
}

// 渲染毛玻璃 TabBar
function renderFrostedTabBar(props: BottomTabBarProps) {
  return <FrostedTabBar {...props} />;
}

// 个人中心 Stack
function ProfileNavigator() {
  return (
    <ProfileStack.Navigator
      screenOptions={{ headerShown: false, animation: 'slide_from_right' }}
    >
      <ProfileStack.Screen name="ProfileMain" component={ProfileScreen} />
      <ProfileStack.Screen name="EditProfile" component={EditProfileScreen} />
    </ProfileStack.Navigator>
  );
}

// 主应用 Tab 导航
// 底部Tab
function MainNavigator() {
  return (
    <Tab.Navigator
      tabBar={renderFrostedTabBar}
      screenOptions={{
        headerShown: false,
        tabBarHideOnKeyboard: true,
        lazy: true,
      }}
    >
      <Tab.Screen
        name="HomeTab"
        component={HomeNavigator}
        options={{ title: '首页' }}
      />
      <Tab.Screen
        name="RecognitionTab"
        component={RecognitionScreen}
        options={{ title: '识别' }}
      />
      <Tab.Screen
        name="MealTab"
        component={MealPlanScreen}
        options={{ title: '配餐' }}
      />
      <Tab.Screen
        name="TrendsTab"
        component={TrendsScreen}
        options={{ title: '趋势' }}
      />
      <Tab.Screen
        name="ReportsTab"
        component={ReportsScreen}
        options={{ title: '报告' }}
      />
      <Tab.Screen
        name="ProfileTab"
        component={ProfileNavigator}
        options={{ title: '我的' }}
      />
    </Tab.Navigator>
  );
}

// 加载等待闪屏
function SessionSplash() {
  return (
    <View style={styles.splash}>
      <View style={styles.splashOrb} />
      <ActivityIndicator color={colors.blue} size="large" />
      <Text style={styles.splashText}>正在准备健康档案…</Text>
    </View>
  );
}

/** 根路由通过会话状态切换认证区与主应用 */
export function AppNavigator() {
  const status = useSessionStore(state => state.status);
  const hydrate = useSessionStore(state => state.hydrate);

  useEffect(() => {
    hydrate().catch(() => undefined);
  }, [hydrate]);

  if (status === 'restoring') {
    return <SessionSplash />;
  }

  return (
    <NavigationContainer theme={navigationTheme}>
      {status === 'signedIn' ? <MainNavigator /> : <AuthNavigator />}
    </NavigationContainer>
  );
}

const styles = StyleSheet.create({
  splash: {
    flex: 1,
    backgroundColor: colors.canvas,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 14,
    overflow: 'hidden',
  },
  splashOrb: {
    position: 'absolute',
    width: 210,
    height: 210,
    borderRadius: 105,
    backgroundColor: 'rgba(0,113,227,0.12)',
  },
  splashText: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 13,
    fontWeight: '700',
  },
});
