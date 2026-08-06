import React, { useEffect, useRef } from 'react';
import { Animated, Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { BarChart3, Camera, FileText, Home, Sparkles, UserRound } from 'lucide-react-native';

import { GlassSurface } from '../../shared/components/GlassSurface';
import { useTabBarVisibility } from '../../shared/store/tabBarVisibility';
import { colors, fonts } from '../../shared/theme/tokens';

const tabMeta = {
  HomeTab: { label: '首页', Icon: Home },
  RecognitionTab: { label: '识别', Icon: Camera },
  MealTab: { label: '配餐', Icon: Sparkles },
  TrendsTab: { label: '趋势', Icon: BarChart3 },
  ReportsTab: { label: '报告', Icon: FileText },
  ProfileTab: { label: '我的', Icon: UserRound },
} as const;

const BAR_HEIGHT = 52;

/**
 * 模拟稿的悬浮六项底栏：
 * - 紧凑：52 高度 + 大圆角 + 细描边，避免浅色背景下与页面融为一体。
 * - 浅色玻璃：不使用大范围 Skia 光晕或深阴影，消除底部黑色渐变感。
 * - 随滚动隐藏：订阅 useTabBarVisibility，translateY 滑出/滑入（原生走 native driver）。
 * - 无障碍按键仍由 Pressable 提供，Canvas 光晕 pointerEvents 关闭。
 */
export function FrostedTabBar({ state, descriptors, navigation }: BottomTabBarProps) {
  const insets = useSafeAreaInsets();
  const activeIndex = state.index;
  const hidden = useTabBarVisibility(s => s.hidden);
  const setHidden = useTabBarVisibility(s => s.setHidden);
  const translateY = useRef(new Animated.Value(0)).current;

  // 切换 tab 后恢复显示：新页面的 ScrollView 位于顶部时不触发滚动事件，需主动复位。
  useEffect(() => {
    setHidden(false);
    // activeIndex 变化即代表切换成功，无需依赖 setHidden。
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeIndex]);

  useEffect(() => {
    Animated.timing(translateY, {
      toValue: hidden ? 120 : 0,
      duration: 320,
      useNativeDriver: Platform.OS !== 'web',
    }).start();
  }, [hidden, translateY]);

  return (
    <Animated.View style={[styles.barWrap, { bottom: Math.max(insets.bottom, 6), transform: [{ translateY }] }]}>
      <GlassSurface variant="navigation" intensity={58} style={styles.bar}>
        <View style={styles.content}>
          {state.routes.map((route, index) => {
            const meta = tabMeta[route.name as keyof typeof tabMeta];
            const focused = index === activeIndex;
            const Icon = meta.Icon;
            const options = descriptors[route.key].options;
            const onPress = () => {
              const event = navigation.emit({ type: 'tabPress', target: route.key, canPreventDefault: true });
              if (!focused && !event.defaultPrevented) {
                navigation.navigate(route.name);
              }
            };

            return (
              <Pressable
                accessibilityLabel={options.tabBarAccessibilityLabel || meta.label}
                accessibilityRole="button"
                accessibilityState={focused ? { selected: true } : {}}
                key={route.key}
                onLongPress={() => navigation.emit({ type: 'tabLongPress', target: route.key })}
                onPress={onPress}
                style={({ pressed }) => [styles.item, focused && styles.itemFocused, pressed && styles.itemPressed]}
              >
                <Icon color={focused ? colors.blue : '#7A8BA0'} size={18} strokeWidth={focused ? 2.45 : 2.1} />
                <Text style={[styles.label, focused && styles.labelFocused]}>{meta.label}</Text>
              </Pressable>
            );
          })}
        </View>
      </GlassSurface>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  barWrap: { position: 'absolute', left: 12, right: 12, zIndex: 120 },
  bar: {
    height: BAR_HEIGHT,
    borderRadius: 20,
    boxShadow: '0 2px 8px rgba(100, 116, 139, 0.10)',
  },
  content: { flex: 1, flexDirection: 'row', alignItems: 'stretch' },
  item: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 1, borderRadius: 14, marginVertical: 4 },
  itemFocused: {
    backgroundColor: 'rgba(0, 113, 227, 0.10)',
    borderColor: 'rgba(0, 113, 227, 0.16)',
    borderWidth: StyleSheet.hairlineWidth,
  },
  itemPressed: { opacity: 0.74, transform: [{ scale: 0.96 }] },
  label: { color: '#7A8BA0', fontFamily: fonts.body, fontSize: 8.5, fontWeight: '700' },
  labelFocused: { color: colors.blue },
});
