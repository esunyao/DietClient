import { create } from 'zustand';

/**
 * 底部 tab 随滚动隐藏的共享状态。
 * AppScreen 的 ScrollView 上报方向翻转（仅翻转时 set，避免每帧重渲染），
 * FrostedTabBar 订阅后驱动 translateY 动画。
 */
interface TabBarVisibilityState {
  hidden: boolean;
  setHidden: (hidden: boolean) => void;
}

export const useTabBarVisibility = create<TabBarVisibilityState>(set => ({
  hidden: false,
  setHidden: hidden => set({ hidden }),
}));
