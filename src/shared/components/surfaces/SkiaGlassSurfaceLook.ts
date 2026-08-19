/**
 * 玻璃变体的静态视觉层（纯函数，便于单测与跨端一致）。
 * 数值对齐旧实现：iOS BlurView（backgroundColor/overlayColor/reducedTransparencyFallbackColor）、
 * Android drawable（bg_glass_navigation / bg_glass_soft）与 JS theme token。
 */

export type GlassVariant = 'frosted' | 'soft' | 'navigation';

export interface GlassLook {
  /** 全矩形白底：圆角外露出的角落与无快照时的基底。 */
  baseFill: string;
  /** 覆盖在模糊快照之上的白色覆盖层；null 表示不叠加。 */
  overlay: string | null;
  /** 1px 描边色。 */
  border: string;
  /** 顶部高光渐变的起始色（向透明渐变）。 */
  sheen: string;
  /** 是否参与背景捕获（soft 不捕获，零成本）。 */
  needsCapture: boolean;
}

export const GLASS_LOOKS: Record<GlassVariant, GlassLook> = {
  frosted: {
    // 对齐旧 BlurView：backgroundColor rgba(255,255,255,0.24) + overlayColor rgba(255,255,255,0.34)
    baseFill: 'rgba(255, 255, 255, 0.24)',
    overlay: 'rgba(255, 255, 255, 0.34)',
    border: 'rgba(255, 255, 255, 0.98)', // glass.borderStrong
    sheen: 'rgba(255, 255, 255, 0.34)', // glass.sheen
    needsCapture: true,
  },
  soft: {
    // 纯静态层：glass.tintSoft + 细白描边 + 顶部高光
    baseFill: 'rgba(255, 255, 255, 0.54)',
    overlay: null,
    border: 'rgba(255, 255, 255, 0.78)',
    sheen: 'rgba(255, 255, 255, 0.34)',
    needsCapture: false,
  },
  navigation: {
    // 对齐旧 navigationSurface：backgroundColor rgba(255,255,255,0.66) + overlayColor
    baseFill: 'rgba(255, 255, 255, 0.66)',
    overlay: 'rgba(255, 255, 255, 0.34)',
    border: 'rgba(148, 163, 184, 0.48)',
    sheen: 'rgba(255, 255, 255, 0.68)',
    needsCapture: true,
  },
};

/** 液态模式基底：对齐 Android bg_glass_navigation 填充 #E0FFFFFF（0.878）。 */
export const LIQUID_BASE_FILL = 'rgba(255, 255, 255, 0.88)';

/** 液态模式覆盖层：对齐 Android AndroidGlassSurface fillPaint（alpha 42 ≈ 0.165）。 */
export const LIQUID_OVERLAY_FILL = 'rgba(255, 255, 255, 0.165)';

/** iOS Reduce Transparency 兜底纯色（对齐 reducedTransparencyFallbackColor）。 */
export const OPAQUE_FALLBACK_FILL = '#FFFFFF';

/** 触摸光晕半径（canvas 单位），对齐原生 max(width, height) * 0.55。 */
export function glowRadiusForSize(width: number, height: number): number {
  return Math.max(width, height) * 0.55;
}

/**
 * intensity（0-100）→ 非液态模糊半径（canvas 单位）。
 * 起点 0.25（intensity=50 → 12.5），视觉对齐时在此集中调整。
 */
export function blurRadiusForIntensity(intensity: number): number {
  return Math.max(0, intensity * 0.25);
}
