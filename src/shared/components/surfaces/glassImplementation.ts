export type GlassImplementation = 'native' | 'skia';
export type GlassPlatform = 'android' | 'ios' | 'web' | 'windows' | 'macos' | 'unknown';
export type GlassMaterialVariant = 'frosted' | 'soft' | 'navigation';

/**
 * 选择玻璃渲染路径：iOS 的实时导航材质不经过窗口快照，避免宿主自身被拍入背景。
 */
export function resolveGlassImplementation(
  platform: GlassPlatform,
  variant: GlassMaterialVariant,
  configured: GlassImplementation = 'skia',
): GlassImplementation {
  if (configured === 'native' || (platform === 'ios' && variant !== 'soft')) {
    return 'native';
  }
  return 'skia';
}
