import { Easing, ReduceMotion, type WithSpringConfig, type WithTimingConfig } from 'react-native-reanimated';

/**
 * 全局动画参数的唯一来源。
 * 组件只引用这里的常量，不写魔法数字；调优时集中改这一处。
 * 所有动画都由 reanimated 驱动，默认 `reduceMotion: System`，
 * 系统开启"减弱动态效果"时自动直达终值。
 */

/** 动效时长按用途分组；页面不再自行散落时长。 */
export const motion = {
  micro: {
    pressIn: 85,
    touchOut: 140,
    toastIn: 220,
    toastOut: 160,
  },
  navigation: {
    screenTransition: 200,
    sheetIn: 220,
    sheetOut: 160,
    tabBarSlide: 220,
    tabIndicator: 220,
    headerCollapse: 220,
  },
  data: {
    barGrow: 560,
    ringSweep: 720,
    countUp: 400,
    scanSweep: 1600,
    breath: 1200,
  },
} as const;

/** 兼容既有调用方的扁平别名。 */
export const durations = {
  ...motion.navigation,
  ...motion.data,
  ...motion.micro,
} as const;

/** 弹簧：轻快，用于选中态与短距离移动。 */
export const springSnappy: WithSpringConfig = {
  damping: 20,
  stiffness: 250,
  mass: 1,
  reduceMotion: ReduceMotion.System,
};

/** 按压释放：不弹跳，只保留柔和回弹。 */
export const springPress: WithSpringConfig = {
  damping: 24,
  stiffness: 320,
  mass: 0.72,
  reduceMotion: ReduceMotion.System,
};

/** 弹簧：舒缓，用于图表柱与较大位移。 */
export const springGentle: WithSpringConfig = {
  damping: 22,
  stiffness: 180,
  mass: 1,
  reduceMotion: ReduceMotion.System,
};

/** 时间过渡：系统界面使用快速启动、平缓落定的曲线。 */
export function timing(duration: number, easing = Easing.out(Easing.cubic)): WithTimingConfig {
  return {
    duration,
    easing,
    reduceMotion: ReduceMotion.System,
  };
}

/** 导航状态变化使用对称的 in-out 曲线，避免岛式标题切换突然加速。 */
export function navigationTiming(duration: number): WithTimingConfig {
  return timing(duration, Easing.inOut(Easing.cubic));
}
