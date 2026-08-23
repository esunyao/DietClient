import React, { useEffect } from 'react';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';
import { NavigationContainer, DefaultTheme } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

// 认证相关页面
import {
  EmailVerifiedScreen,
  LoginScreen,
  RegisterScreen,
  VerifyEmailScreen,
} from '../features/auth/screens/AuthScreens';
// 会话/登录状态 Store
import { useSessionStore } from '../features/auth/store/sessionStore';
// 饮食/主功能相关页面
import {
  MealPlanScreen,
  ReportsScreen,
  ScoreDetailScreen,
  TrendsScreen,
} from '../features/diet/screens/StaticScreens';
import { HomeScreen } from '../features/diet/screens/StaticScreens';
import { RecognitionScreen } from '../features/diet/screens/RecognitionScreen';
import { MealHistoryScreen } from '../features/diet/screens/MealHistoryScreen';
import { MealDetailScreen } from '../features/diet/screens/MealDetailScreen';
import { MealCorrectionScreen } from '../features/diet/screens/MealCorrectionScreen';
// 个人中心相关页面
import {
  EditProfileScreen,
  ProfileScreen,
} from '../features/profile/screens/ProfileScreens';
import { HealthRecordFormScreen, HealthRecordsScreen } from '../features/profile/screens/HealthRecords';
// 主题 Token
import { colors, fonts } from '../shared/theme/tokens';
// 自定义毛玻璃 TabBar
import { FrostedTabBar } from './components/FrostedTabBar';
// 全局滚动驱动共享状态（UI 线程，供 TabBar 显隐订阅）
import { ScrollChromeProvider } from '../shared/scrollChrome/ScrollChromeProvider';
// 路由类型定义
import type {
  AppTabParamList,
  AuthStackParamList,
  DietStackParamList,
  HomeStackParamList,
  ProfileStackParamList,
} from './types';

const AuthStack = createNativeStackNavigator<AuthStackParamList>();
const HomeStack = createNativeStackNavigator<HomeStackParamList>();
const DietStack = createNativeStackNavigator<DietStackParamList>();
const ProfileStack = createNativeStackNavigator<ProfileStackParamList>();
const Tab = createBottomTabNavigator<AppTabParamList>();

// 认证与首页保留右滑进入；个人页二级界面单独使用原生 fade，减少大卡片横移合成。
const stackAnimation = 'slide_from_right';

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
      screenOptions={{ headerShown: false, animation: stackAnimation }}
    >
      <AuthStack.Screen name="Login" component={LoginScreen} />
      <AuthStack.Screen name="Register" component={RegisterScreen} />
      <AuthStack.Screen name="VerifyEmail" component={VerifyEmailScreen} />
      <AuthStack.Screen name="EmailVerified" component={EmailVerifiedScreen} />
    </AuthStack.Navigator>
  );
}

// 首页模块 Stack
function HomeNavigator() {
  return (
    <HomeStack.Navigator
      screenOptions={{ headerShown: false, animation: stackAnimation }}
    >
      <HomeStack.Screen name="HomeMain" component={HomeScreen} />
      <HomeStack.Screen name="ScoreDetail" component={ScoreDetailScreen} />
    </HomeStack.Navigator>
  );
}

/** 识别页为底栏根页；历史、报告与修正页统一由页面注册表隐藏底栏。 */
function DietNavigator() {
  return (
    <DietStack.Navigator screenOptions={{ headerShown: false, animation: stackAnimation }}>
      <DietStack.Screen name="Recognition" component={RecognitionScreen} />
      <DietStack.Screen name="MealHistory" component={MealHistoryScreen} />
      <DietStack.Screen name="MealDetail" component={MealDetailScreen} />
      <DietStack.Screen name="MealCorrection" component={MealCorrectionScreen} />
    </DietStack.Navigator>
  );
}

// 渲染毛玻璃 TabBar
function renderFrostedTabBar(props: BottomTabBarProps) {
  return <FrostedTabBar {...props} />;
}

// 个人中心 Stack
function ProfileNavigator() {
  const profileOnboardingRequired = useSessionStore(state => state.profileOnboardingRequired);
  return (
    <ProfileStack.Navigator
      initialRouteName={profileOnboardingRequired ? 'EditProfile' : 'ProfileMain'}
      screenOptions={{ headerShown: false, animation: 'fade' }}
    >
      <ProfileStack.Screen name="ProfileMain" component={ProfileScreen} />
      <ProfileStack.Screen name="EditProfile" component={EditProfileScreen} initialParams={{ onboarding: profileOnboardingRequired }} />
      <ProfileStack.Screen name="HealthRecords" component={HealthRecordsScreen} />
      <ProfileStack.Screen name="HealthRecordForm" component={HealthRecordFormScreen} />
    </ProfileStack.Navigator>
  );
}

// 主应用 Tab 导航
// 底部Tab
function MainNavigator() {
  const profileOnboardingRequired = useSessionStore(state => state.profileOnboardingRequired);
  return (
    <Tab.Navigator
      initialRouteName={profileOnboardingRequired ? 'ProfileTab' : 'HomeTab'}
      tabBar={renderFrostedTabBar}
      detachInactiveScreens
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
          component={DietNavigator}
          options={{ title: '记录' }}
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

/** 启动闪屏的静态光球：避免装饰性循环动画抢占首屏与导航资源。 */
function BreathingOrb() {
  return <View style={styles.splashOrb} />;
}

// 加载等待闪屏
function SessionSplash() {
  return (
    <View style={styles.splash}>
      <BreathingOrb />
      <ActivityIndicator color={colors.blue} size="large" />
      <Text style={styles.splashText}>正在准备健康档案…</Text>
    </View>
  );
}

/** 根路由通过会话状态切换认证区与主应用 */
const linking = {
  prefixes: ['diethealth://'],
  config: {
    screens: {
      EmailVerified: 'auth/email-verified',
    },
  },
};

export function AppNavigator() {
  const status = useSessionStore(state => state.status);
  const onboardingResolved = useSessionStore(state => state.onboardingResolved);
  const hydrate = useSessionStore(state => state.hydrate);

  useEffect(() => {
    hydrate().catch(() => undefined);
  }, [hydrate]);

  if (status === 'restoring' || (status === 'signedIn' && !onboardingResolved)) {
    return <SessionSplash />;
  }

  return (
    <NavigationContainer linking={linking} theme={navigationTheme}>
      {status === 'signedIn' ? (
        <ScrollChromeProvider>
          <MainNavigator />
        </ScrollChromeProvider>
      ) : (
        <AuthNavigator />
      )}
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
