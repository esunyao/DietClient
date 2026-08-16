/**
 * 玻璃材质平台入口。
 * Metro（原生）解析到 `GlassSurface.native.tsx`，webpack（Web）解析到 `GlassSurface.web.tsx`；
 * 此 index 仅为 TypeScript 类型解析提供默认实现（原生实现，两平台签名一致）。
 */
export { GlassSurface } from './GlassSurface.native';
