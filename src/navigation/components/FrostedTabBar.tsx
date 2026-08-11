import React, { memo, useCallback, useEffect } from 'react';
import { StyleSheet, Text, View, type LayoutChangeEvent } from 'react-native';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { BarChart3, Camera, FileText, Home, Sparkles, UserRound } from 'lucide-react-native';
import Animated, {
  Easing,
  ReduceMotion,
  useAnimatedStyle,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';

import { durations } from '../../shared/animation/config';
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

/** 胶囊滑动过渡：短时间过渡，不用弹簧（避免过冲与额外合成）。 */
const IndicatorTiming = {
  duration: durations.tabIndicator,
  easing: Easing.inOut(Easing.cubic),
  reduceMotion: ReduceMotion.System,
};

/** 单个 tab 项。memo + 稳定回调让滚动中（父不重渲染）完全跳过重渲染。 */
const TabItem = memo(function ({ meta, focused, routeName, onPressRoute, onLongPressRoute }: {
  meta: (typeof tabMeta)[keyof typeof tabMeta];
  focused: boolean;
  routeName: string;
  onPressRoute: (routeName: string) => void;
  onLongPressRoute: (routeName: string) => void;
}) {
  const Icon = meta.Icon;
  return (
    <PressableScale
      accessibilityLabel={meta.label}
      accessibilityRole="button"
      accessibilityState={focused ? { selected: true } : {}}
      onLongPress={() => onLongPressRoute(routeName)}
      onPress={() => onPressRoute(routeName)}
      scaleTo={0.98}
      style={styles.item}
    >
      <Icon color={focused ? colors.blue : '#7A8BA0'} size={18} strokeWidth={focused ? 2.45 : 2.1} />
      <Text style={[styles.label, focused && styles.labelFocused]}>{meta.label}</Text>
    </PressableScale>
  );
});

/**
 * 模拟稿的悬浮六项底栏：
 * - 紧凑：52 高度 + 大圆角 + 细描边，避免浅色背景下与页面融为一体。
 * - 浅色玻璃：不使用大范围 Skia 光晕或深阴影，消除底部黑色渐变感。
 * - 选中胶囊：reanimated 驱动 translateX 滑动（onLayout 测量宽度，切 tab 一次性过渡）。
 * - 随滚动隐藏：translateY 由 UI 线程 tabHidden 驱动（带过渡动画）。
 */
export function FrostedTabBar({ state, navigation }: BottomTabBarProps) {
  const insets = useSafeAreaInsets();
  const activeIndex = state.index;
  const chrome = useScrollChrome();

  // 选中胶囊：像素级 left/width（UI 线程，一次性过渡）。
  const barWidth = useSharedValue(0);
  const indicatorLeft = useSharedValue(0);

  // 随滚动隐藏：translateY 由 UI 线程的 tabHidden 驱动（带过渡动画，非跳变）。
  const wrapStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: chrome.tabHidden.value * 120 }],
  }));
  const indicatorStyle = useAnimatedStyle(() => ({
    left: indicatorLeft.value,
    width: barWidth.value / state.routes.length,
  }));

  const onBarLayout = (event: LayoutChangeEvent) => {
    const width = event.nativeEvent.layout.width;
    barWidth.value = width;
    indicatorLeft.value = activeIndex * (width / state.routes.length);
  };

  // 切换 tab 后恢复显示（新页面顶部不触发滚动事件，需主动复位），并让胶囊滑动到新位置。
  useEffect(() => {
    chrome.resetTabBar();
    if (barWidth.value > 0) {
      indicatorLeft.value = withTiming(activeIndex * (barWidth.value / state.routes.length), IndicatorTiming);
    }
    // activeIndex 变化即代表切换成功。
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeIndex]);

  // 稳定回调：activeIndex 变化时重建，但滚动期间（父不重渲染）保持引用稳定，memo 生效。
  const onPressRoute = useCallback((routeName: string) => {
    const index = state.routes.findIndex(route => route.name === routeName);
    const route = state.routes[index];
    if (!route) return;
    const event = navigation.emit({ type: 'tabPress', target: route.key, canPreventDefault: true });
    if (index !== activeIndex && !event.defaultPrevented) {
      navigation.navigate(route.name);
    }
  }, [activeIndex, navigation, state.routes]);

  const onLongPressRoute = useCallback((routeName: string) => {
    const route = state.routes.find(r => r.name === routeName);
    if (route) navigation.emit({ type: 'tabLongPress', target: route.key });
  }, [navigation, state.routes]);

  return (
    <Animated.View style={[styles.barWrap, { bottom: Math.max(insets.bottom, 6) }, wrapStyle]}>
      <GlassSurface variant="navigation" intensity={50} style={styles.bar}>
        <View style={styles.content} onLayout={onBarLayout}>
          <Animated.View pointerEvents="none" style={[styles.indicator, indicatorStyle]} />
          {state.routes.map((route, index) => {
            const meta = tabMeta[route.name as keyof typeof tabMeta];
            return (
              <TabItem
                key={route.key}
                meta={meta}
                focused={index === activeIndex}
                routeName={route.name}
                onPressRoute={onPressRoute}
                onLongPressRoute={onLongPressRoute}
              />
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
