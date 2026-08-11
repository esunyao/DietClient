import React, { createContext, useCallback, useContext, useMemo } from 'react';
import {
  Easing,
  ReduceMotion,
  makeMutable,
  useSharedValue,
  withTiming,
  type SharedValue,
} from 'react-native-reanimated';

import { durations } from '../animation/config';

/**
 * 全局滚动驱动共享状态（UI 线程）。
 *
 * 目标：让"底部 tab 随滚动隐藏"由 Reanimated worklet 在 UI 线程直接计算，
 * 避免 AppScreen 用 JS onScroll + setState 每帧驱动（这是滚动卡顿的 JS 线程瓶颈）。
 * FrostedTabBar 通过 useAnimatedStyle 订阅 tabHidden 获得流畅的 translateY 过渡。
 *
 * 设计要点：
 * - `tabHidden` 是全局唯一的（FrostedTabBar 只有一个实例）。
 * - `tabHiddenLogical` 是与动画值分离的逻辑态（0/1），供 worklet 判向，
 *   避免 withTiming 在 220ms 过渡期内被逐帧重赋值、动画永远无法结束。
 * - `headerCollapsed` **不放在这里**：它是每屏状态（栈内各屏需独立保持），
 *   由每个 AppScreen 自建 shared value，经 HeaderCollapsedContext 下发给 ScreenHeader。
 * - 提供 provider 外的 fallback 单例，避免在未包裹处使用组件时崩溃。
 */

export interface ScrollChrome {
  /** 全局滚动偏移（信息用，暂供调试）。 */
  scrollY: SharedValue<number>;
  /** tabbar 隐藏进度：0 显示 / 1 隐藏（含过渡中间值），FrostedTabBar 订阅。 */
  tabHidden: SharedValue<number>;
  /** tabHidden 的逻辑态（0/1），与动画值分开，供 worklet 判向避免重触发。 */
  tabHiddenLogical: SharedValue<number>;
  /** JS 侧命令式隐藏/显示（头像编辑抽屉等）。 */
  setTabHidden: (hidden: boolean) => void;
  /** 切 tab 时把 tabbar 复位为显示（瞬时，不做动画）。 */
  resetTabBar: () => void;
}

const SlideTiming = {
  duration: durations.tabBarSlide,
  easing: Easing.inOut(Easing.cubic),
  reduceMotion: ReduceMotion.System,
};

// Provider 外的兜底单例：避免 AppScreen 等组件在未包裹处因 context 为空而崩溃。
const fallbackChrome: ScrollChrome = {
  scrollY: makeMutable(0),
  tabHidden: makeMutable(0),
  tabHiddenLogical: makeMutable(0),
  setTabHidden: () => {},
  resetTabBar: () => {},
};

const ScrollChromeContext = createContext<ScrollChrome>(fallbackChrome);

export function ScrollChromeProvider({ children }: { children: React.ReactNode }) {
  const scrollY = useSharedValue(0);
  const tabHidden = useSharedValue(0);
  const tabHiddenLogical = useSharedValue(0);

  const setTabHidden = useCallback(
    (hidden: boolean) => {
      tabHiddenLogical.value = hidden ? 1 : 0;
      tabHidden.value = hidden ? withTiming(1, SlideTiming) : withTiming(0, SlideTiming);
    },
    [tabHidden, tabHiddenLogical],
  );

  const resetTabBar = useCallback(() => {
    tabHiddenLogical.value = 0;
    tabHidden.value = 0; // 瞬时复位，不做过渡
  }, [tabHidden, tabHiddenLogical]);

  const value = useMemo(
    () => ({ scrollY, tabHidden, tabHiddenLogical, setTabHidden, resetTabBar }),
    [scrollY, tabHidden, tabHiddenLogical, setTabHidden, resetTabBar],
  );

  return <ScrollChromeContext.Provider value={value}>{children}</ScrollChromeContext.Provider>;
}

export function useScrollChrome(): ScrollChrome {
  return useContext(ScrollChromeContext);
}
