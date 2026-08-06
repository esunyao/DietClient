import { Platform } from 'react-native';

/**
 * 设计 token 来自 htmlTest 的蓝绿健康语言。
 * 组件只引用 token，后续调整品牌色时不会散落修改页面样式。
 */
export const colors = {
  canvas: '#F5F8FC',
  surface: '#FFFFFF',
  ink: '#0F172A',
  muted: '#64748B',
  line: '#E6EDF5',
  blue: '#0071E3',
  green: '#34C759',
  amber: '#FF9500',
  red: '#FF3B30',
  violet: '#6D5DFB',
  blueSoft: '#EAF4FF',
  greenSoft: '#EAF9EF',
  amberSoft: '#FFF5E8',
  redSoft: '#FFF0EF',
  glass: 'rgba(255, 255, 255, 0.58)',
  glassStrong: 'rgba(255, 255, 255, 0.78)',
  glassBorder: 'rgba(255, 255, 255, 0.88)',
};

export const radii = {
  sm: 12,
  md: 18,
  lg: 26,
  pill: 999,
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
  display: Platform.select({ web: 'Inter, system-ui, sans-serif', ios: 'System', android: 'sans-serif' }),
  body: Platform.select({ web: 'Inter, system-ui, sans-serif', ios: 'System', android: 'sans-serif' }),
  mono: Platform.select({ web: 'ui-monospace, SFMono-Regular, monospace', ios: 'Menlo', android: 'monospace' }),
};
