import { Platform } from 'react-native';

/**1
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

/** 玻璃材质相关 token：外壳（顶栏/底栏）用强玻璃，信息密集卡用 soft 玻璃。 */
export const glass = {
  border: 'rgba(255, 255, 255, 0.88)',
  borderStrong: 'rgba(255, 255, 255, 0.98)',
  /** 顶部内高光，仿 iOS 材质的高光描边。 */
  sheen: 'rgba(255, 255, 255, 0.34)',
  /** 半透明白底色：值越低越透出背景光斑（玻璃感更强）。 */
  tint: 'rgba(255, 255, 255, 0.50)',
  // 信息卡只用一层轻薄白底；过高的不透明度会把背景光斑洗成一片白雾。
  tintSoft: 'rgba(255, 255, 255, 0.54)',
};

/** 背景光斑与 tab 光晕用色，统一收敛到 token，避免散落硬编码。 */
export const glow = {
  orbBlue: 'rgba(0, 113, 227, 0.12)',
  orbGreen: 'rgba(52, 199, 89, 0.10)',
  orbViolet: 'rgba(109, 93, 251, 0.09)',
  blue: 'rgba(0, 113, 227, 0.22)',
  green: 'rgba(52, 199, 89, 0.07)',
  white: 'rgba(255, 255, 255, 0.72)',
  violet: 'rgba(109, 93, 251, 0.09)',
};

/** 常用投影，扁平外壳用软阴影，卡片与 tab 用分层阴影。 */
export const shadows = {
  soft: '0 4px 16px rgba(91, 120, 149, 0.10)',
  card: '0 8px 18px rgba(91, 120, 149, 0.10)',
  tab: '0 12px 28px rgba(58, 90, 120, 0.16)',
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
