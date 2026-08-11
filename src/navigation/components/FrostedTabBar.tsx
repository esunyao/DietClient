import React, { useEffect } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { BarChart3, Camera, FileText, Home, Sparkles, UserRound } from 'lucide-react-native';
import Animated, { useAnimatedStyle } from 'react-native-reanimated';

import { PressableScale } from '../../shared/animation/PressableScale';
import { GlassSurface } from '../../shared/components/GlassSurface';
import { useScrollChrome } from '../../shared/scrollChrome/ScrollChromeProvider';
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
/** 选中胶囊相对 item 的纵向内缩。 */
const INDICATOR_TOP = 4;
const INDICATOR_BOTTOM = 4;

/**
 * 模拟稿的悬浮六项底栏：
 * - 紧凑：52 高度 + 大圆角 + 细描边，避免浅色背景下与页面融为一体。
 * - 浅色玻璃：不使用大范围 Skia 光晕或深阴影，消除底部黑色渐变感。
 * - 选中胶囊：直接切换位置，避免切 tab 时额外合成。
 * - 随滚动隐藏：直接滑出/滑入，避免切屏与底栏动画叠加。
 * - 无障碍按键仍由 PressableScale 提供。
 */
export function FrostedTabBar({ state, descriptors, navigation }: BottomTabBarProps) {
  const insets = useSafeAreaInsets();
  const activeIndex = state.index;
  const chrome = useScrollChrome();

  // 随滚动隐藏：translateY 由 UI 线程的 tabHidden 驱动（带过渡动画，非跳变）。
  const wrapStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: chrome.tabHidden.value * 120 }],
  }));

  // 切换 tab 后恢复显示：新页面的 ScrollView 位于顶部时不触发滚动事件，需主动复位。
  useEffect(() => {
    chrome.resetTabBar();
    // activeIndex 变化即代表切换成功。
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeIndex]);

  const itemWidth = 100 / state.routes.length;

  return (
    <Animated.View style={[styles.barWrap, { bottom: Math.max(insets.bottom, 6) }, wrapStyle]}>
      <GlassSurface variant="navigation" intensity={50} style={styles.bar}>
        <View style={styles.content}>
          <View pointerEvents="none" style={[styles.indicator, { left: `${activeIndex * itemWidth}%`, width: `${itemWidth}%` }]} />
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
              <PressableScale
                accessibilityLabel={options.tabBarAccessibilityLabel || meta.label}
                accessibilityRole="button"
                accessibilityState={focused ? { selected: true } : {}}
                key={route.key}
                onLongPress={() => navigation.emit({ type: 'tabLongPress', target: route.key })}
                onPress={onPress}
                scaleTo={0.98}
                style={styles.item}
              >
                <Icon color={focused ? colors.blue : '#7A8BA0'} size={18} strokeWidth={focused ? 2.45 : 2.1} />
                <Text style={[styles.label, focused && styles.labelFocused]}>{meta.label}</Text>
              </PressableScale>
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
  /** 选中胶囊：绝对定位，按当前 tab 直接切换。 */
  indicator: {
    position: 'absolute',
    top: INDICATOR_TOP,
    bottom: INDICATOR_BOTTOM,
    borderRadius: 14,
    backgroundColor: 'rgba(0, 113, 227, 0.10)',
    borderColor: 'rgba(0, 113, 227, 0.16)',
    borderWidth: StyleSheet.hairlineWidth,
  },
  item: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 1, borderRadius: 14, marginVertical: 4 },
  label: { color: '#7A8BA0', fontFamily: fonts.body, fontSize: 8.5, fontWeight: '700' },
  labelFocused: { color: colors.blue },
});
