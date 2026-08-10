import { Easing, ReduceMotion, type WithSpringConfig, type WithTimingConfig } from 'react-native-reanimated';

/**
 * 全局动画参数的唯一来源。
 * 组件只引用这里的常量，不写魔法数字；调优时集中改这一处。
 * 所有动画都由 reanimated 驱动，默认 `reduceMotion: System`，
 * 系统开启"减弱动态效果"时自动直达终值。
 */

/** 各动效时长（毫秒） */
export const durations = {
  /** 页面进入淡入（Web，挂载时一次） */
  screenTransition: 180,
  /** 进度条填充生长 */
  barGrow: 650,
  /** 评分环扫入 */
  ringSweep: 850,
  /** 数字滚动 */
  countUp: 450,
  /** Toast 进入 */
  toastIn: 220,
  /** Toast 退出 */
  toastOut: 160,
  /** Tab 栏滑出/滑入 */
  tabBarSlide: 320,
  /** 头部折叠 */
  headerCollapse: 180,
  /** 按压透明度过渡 */
  pressFade: 90,
  /** 识别页扫描线单程时长 */
  scanSweep: 1600,
  /** 启动闪屏光球呼吸单程时长 */
  breath: 1200,
} as const;

/** 弹簧：轻快，用于按压反馈与胶囊指示器。 */
export const springSnappy: WithSpringConfig = {
  damping: 16,
  stiffness: 260,
  mass: 1,
  reduceMotion: ReduceMotion.System,
};

/** 弹簧：舒缓，用于图表柱与较大位移。 */
export const springGentle: WithSpringConfig = {
  damping: 22,
  stiffness: 180,
  mass: 1,
  reduceMotion: ReduceMotion.System,
};

/** 时间过渡：in-out 三次缓动。 */
export function timing(duration: number): WithTimingConfig {
  return {
    duration,
    easing: Easing.inOut(Easing.cubic),
    reduceMotion: ReduceMotion.System,
  };
}
