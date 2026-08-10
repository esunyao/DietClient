import React, { useCallback, useEffect, useRef } from 'react';
import { StyleSheet, Text, View, type LayoutChangeEvent } from 'react-native';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { BarChart3, Camera, FileText, Home, Sparkles, UserRound } from 'lucide-react-native';
import Animated, { useAnimatedStyle, useSharedValue, withSpring, withTiming } from 'react-native-reanimated';

import { PressableScale } from '../../shared/animation/PressableScale';
import { durations, springSnappy, timing } from '../../shared/animation/config';
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
/** 选中胶囊相对 item 的纵向内缩。 */
const INDICATOR_TOP = 4;
const INDICATOR_BOTTOM = 4;

/**
 * 模拟稿的悬浮六项底栏：
 * - 紧凑：52 高度 + 大圆角 + 细描边，避免浅色背景下与页面融为一体。
 * - 浅色玻璃：不使用大范围 Skia 光晕或深阴影，消除底部黑色渐变感。
 * - 选中胶囊：reanimated 驱动 translateX 弹簧滑动（onLayout 测量各 item 的 x，宽度固定六等分）。
 * - 随滚动隐藏：订阅 useTabBarVisibility，translateY 滑出/滑入（reanimated，UI 线程）。
 * - 无障碍按键仍由 PressableScale 提供。
 */
export function FrostedTabBar({ state, descriptors, navigation }: BottomTabBarProps) {
  const insets = useSafeAreaInsets();
  const activeIndex = state.index;
  const hidden = useTabBarVisibility(s => s.hidden);
  const setHidden = useTabBarVisibility(s => s.setHidden);

  // 选中胶囊指示器：onLayout 记录各 item 的 x，切换时弹簧滑动 translateX（只动 transform）。
  const itemLayouts = useRef<number[]>([]);
  const hasMeasured = useRef(false);
  const indicatorX = useSharedValue(0);
  // 随滚动滑出/滑入。
  const translateY = useSharedValue(0);

  // 切换 tab 后恢复显示：新页面的 ScrollView 位于顶部时不触发滚动事件，需主动复位。
  useEffect(() => {
    setHidden(false);
    // activeIndex 变化即代表切换成功，无需依赖 setHidden。
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeIndex]);

  useEffect(() => {
    translateY.value = withTiming(hidden ? 120 : 0, timing(durations.tabBarSlide));
  }, [hidden, translateY]);

  const moveIndicator = useCallback((index: number, animated = true) => {
    const x = itemLayouts.current[index];
    if (x === undefined) return;
    if (!animated || !hasMeasured.current) {
      // 首次或尺寸变化：直接 snap，避免首帧弹跳。
      indicatorX.value = x;
      hasMeasured.current = true;
    } else {
      indicatorX.value = withSpring(x, springSnappy);
    }
  }, [indicatorX]);

  useEffect(() => {
    moveIndicator(activeIndex);
  }, [activeIndex, moveIndicator]);

  const capsuleStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: indicatorX.value }],
  }));
  const barStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: translateY.value }],
  }));

  const onItemLayout = (index: number) => (event: LayoutChangeEvent) => {
    itemLayouts.current[index] = event.nativeEvent.layout.x;
    if (index === activeIndex) {
      moveIndicator(index, false);
    }
  };

  return (
    <Animated.View style={[styles.barWrap, { bottom: Math.max(insets.bottom, 6) }, barStyle]}>
      <GlassSurface variant="navigation" intensity={58} style={styles.bar}>
        <View style={styles.content}>
          <Animated.View pointerEvents="none" style={[styles.indicator, capsuleStyle]} />
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
                onLayout={onItemLayout(index)}
                onLongPress={() => navigation.emit({ type: 'tabLongPress', target: route.key })}
                onPress={onPress}
                scaleTo={0.92}
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
  /** 选中胶囊：绝对定位，宽度固定为六等分，translateX 由 reanimated 弹簧驱动（只动 transform）。 */
  indicator: {
    position: 'absolute',
    top: INDICATOR_TOP,
    bottom: INDICATOR_BOTTOM,
    left: 0,
    width: '16.6666666666667%',
    borderRadius: 14,
    backgroundColor: 'rgba(0, 113, 227, 0.10)',
    borderColor: 'rgba(0, 113, 227, 0.16)',
    borderWidth: StyleSheet.hairlineWidth,
  },
  item: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 1, borderRadius: 14, marginVertical: 4 },
  label: { color: '#7A8BA0', fontFamily: fonts.body, fontSize: 8.5, fontWeight: '700' },
  labelFocused: { color: colors.blue },
});
