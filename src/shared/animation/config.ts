import { Easing, ReduceMotion, type WithSpringConfig, type WithTimingConfig } from 'react-native-reanimated';

/**
 * 全局动画参数的唯一来源。
 * 组件只引用这里的常量，不写魔法数字；调优时集中改这一处。
 * 所有动画都由 reanimated 驱动，默认 `reduceMotion: System`，
 * 系统开启"减弱动态效果"时自动直达终值。
 */

/** 动效时长（毫秒）：微交互短促、导航连贯、数据反馈克制。 */
export const durations = {
  /** 页面进入淡入（Web，挂载时一次） */
  screenTransition: 200,
  /** 进度条填充生长 */
  barGrow: 560,
  /** 评分环扫入 */
  ringSweep: 720,
  /** 数字滚动 */
  countUp: 400,
  /** Toast 进入 */
  toastIn: 220,
  /** Toast 退出 */
  toastOut: 160,
  /** 底部弹层进入/退出 */
  sheetIn: 220,
  sheetOut: 160,
  /** Tab 栏滑出/滑入 */
  tabBarSlide: 220,
  /** Tab 选中胶囊。 */
  tabIndicator: 220,
  /** 头部折叠 */
  headerCollapse: 220,
  /** 按下反馈 */
  pressIn: 85,
  /** 识别页扫描线单程时长 */
  scanSweep: 1600,
  /** 启动闪屏光球呼吸单程时长 */
  breath: 1200,
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
export function timing(duration: number): WithTimingConfig {
  return {
    duration,
    easing: Easing.out(Easing.cubic),
    reduceMotion: ReduceMotion.System,
  };
}
