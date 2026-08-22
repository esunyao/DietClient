import { materials } from '../../theme/tokens';

/**
 * 玻璃变体的静态视觉层（纯函数，便于单测与跨端一致）。
 * 内容层保持实体白面；仅悬浮导航和弹层透出背景。
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
    baseFill: materials.frostedBase,
    overlay: materials.frostedOverlay,
    border: materials.chromeBorder,
    sheen: materials.sheen,
    needsCapture: true,
  },
  soft: {
    // 信息密集卡不模糊背景，保证阅读稳定。
    baseFill: materials.contentFill,
    overlay: null,
    border: materials.contentBorder,
    sheen: 'rgba(255, 255, 255, 0)',
    needsCapture: false,
  },
  navigation: {
    baseFill: materials.chromeBase,
    overlay: materials.chromeOverlay,
    border: materials.chromeBorder,
    sheen: materials.sheen,
    needsCapture: true,
  },
};

/** 液态模式是显式 opt-in；默认导航不会使用折射或弹性形变。 */
export const LIQUID_BASE_FILL = 'rgba(255, 255, 255, 0.70)';

/** 液态模式覆盖层。 */
export const LIQUID_OVERLAY_FILL = 'rgba(255, 255, 255, 0.12)';

/** iOS Reduce Transparency 兜底纯色。 */
export const OPAQUE_FALLBACK_FILL = materials.contentFill;

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
