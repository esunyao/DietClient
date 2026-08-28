import { Platform } from 'react-native';

/**
 * 浅色系统主题：内容保持安静，系统蓝只承担交互与焦点，语义色只表达健康状态。
 * 组件只引用 token，避免页面各自调出不同的“白卡 + 蓝绿光晕”。
 */
export const colors = {
  canvas: '#F2F2F7',
  surface: '#FFFFFF',
  surfaceMuted: '#F7F7F8',
  ink: '#1D1D1F',
  muted: '#6E6E73',
  placeholder: '#8E8E93',
  line: 'rgba(60, 60, 67, 0.18)',
  blue: '#007AFF',
  green: '#34C759',
  amber: '#FF9500',
  red: '#FF3B30',
  greenInk: '#187A49',
  amberInk: '#9A5B00',
  redInk: '#C93025',
  blueSoft: '#E8F1FF',
  greenSoft: '#EAF8EF',
  amberSoft: '#FFF4E5',
  redSoft: '#FFF0EF',
  inverse: '#FFFFFF',
  scrim: 'rgba(0, 0, 0, 0.26)',
};

export const radii = {
  sm: 12,
  md: 18,
  lg: 26,
  pill: 999,
};

/**
 * 材质只分两层：内容面为实体表面，悬浮导航才允许透出背景。
 * 这样不会把信息卡堆成白雾，也让模糊成本留给真正需要深度的地方。
 */
export const materials = {
  contentFill: '#FFFFFF',
  contentBorder: 'rgba(60, 60, 67, 0.12)',
  chromeBase: 'rgba(255, 255, 255, 0.64)',
  chromeOverlay: 'rgba(255, 255, 255, 0.20)',
  chromeBorder: 'rgba(255, 255, 255, 0.74)',
  frostedBase: 'rgba(255, 255, 255, 0.46)',
  frostedOverlay: 'rgba(255, 255, 255, 0.24)',
  sheen: 'rgba(255, 255, 255, 0.58)',
};

/** 常用投影，扁平外壳用软阴影，卡片与 tab 用分层阴影。 */
export const shadows = {
  soft: '0 2px 8px rgba(0, 0, 0, 0.06)',
  card: '0 4px 14px rgba(0, 0, 0, 0.07)',
  tab: '0 10px 28px rgba(0, 0, 0, 0.14)',
};

export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 32,
};

/** Web 用 Inter，原生端平稳回退到各平台系统字体。 */
export const fonts = {
  display: Platform.select({
    web: 'Inter, system-ui, sans-serif',
    ios: 'System',
    android: 'sans-serif',
  }),
  body: Platform.select({
    web: 'Inter, system-ui, sans-serif',
    ios: 'System',
    android: 'sans-serif',
  }),
  mono: Platform.select({
    web: 'ui-monospace, SFMono-Regular, monospace',
    ios: 'Menlo',
    android: 'monospace',
  }),
};
