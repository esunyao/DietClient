/**
 * 液态玻璃 SkSL —— 移植自 android/app/src/main/res/raw/liquid_glass_effect.agsl。
 *
 * 采样坐标约定与原生捕获一致：content.eval((coord + sourceOffset) * contentScale)
 * - coord/sourceOffset 始终为 Skia 的逻辑坐标（dp/points）；
 * - contentScale 包含捕获降采样与 Android 物理 px → dp 的换算。
 * 因此 shader 无需感知平台像素密度。
 */
export const LIQUID_GLASS_SKSL = `
uniform shader content;
uniform float2 size;
uniform float2 cornerRadii;
uniform float refractionHeight;
uniform float refractionAmount;
uniform float chromaticAberration;
uniform float blurRadius;
uniform float2 sourceOffset;
uniform float contentScale;

float radiusAt(float2 coord, float2 radii) {
    return coord.y < 0.0 ? radii.x : radii.y;
}

float sdRoundedRect(float2 coord, float2 halfSize, float radius) {
    float2 cornerCoord = abs(coord) - (halfSize - float2(radius));
    float outside = length(max(cornerCoord, 0.0)) - radius;
    float inside = min(max(cornerCoord.x, cornerCoord.y), 0.0);
    return outside + inside;
}

float safeSign(float value) {
    return value < 0.0 ? -1.0 : 1.0;
}

float2 safeNormalize(float2 value, float2 fallback) {
    float len = length(value);
    return len > 0.001 ? value / len : fallback;
}

float2 gradRoundedRect(float2 coord, float2 halfSize, float radius) {
    float2 cornerCoord = abs(coord) - (halfSize - float2(radius));
    if (cornerCoord.x >= 0.0 || cornerCoord.y >= 0.0) {
        float2 outside = max(cornerCoord, 0.0);
        float outsideLength = length(outside);
        if (outsideLength > 0.001) return sign(coord) * (outside / outsideLength);
        float useX = step(cornerCoord.y, cornerCoord.x);
        return float2(useX * safeSign(coord.x), (1.0 - useX) * safeSign(coord.y));
    }
    float useX = step(cornerCoord.y, cornerCoord.x);
    return sign(coord) * float2(useX, 1.0 - useX);
}

float circleMap(float x) {
    return 1.0 - sqrt(max(0.0, 1.0 - x * x));
}

// 快照 Bitmap 按 contentScale 降采样，采样坐标统一换算回 content 空间。
half4 sampleContent(float2 coord) {
    return content.eval((coord + sourceOffset) * contentScale);
}

// 对小型导航区域使用固定 3x3 高斯采样；blurRadius 由调用方换算为 content 空间半径。
half4 blurredContent(float2 coord) {
    float r = max(0.01, blurRadius);
    half4 result = sampleContent(coord) * 0.20418;
    result += sampleContent(coord + float2(r, 0.0)) * 0.12384;
    result += sampleContent(coord + float2(-r, 0.0)) * 0.12384;
    result += sampleContent(coord + float2(0.0, r)) * 0.12384;
    result += sampleContent(coord + float2(0.0, -r)) * 0.12384;
    result += sampleContent(coord + float2(r, r)) * 0.07511;
    result += sampleContent(coord + float2(-r, r)) * 0.07511;
    result += sampleContent(coord + float2(r, -r)) * 0.07511;
    result += sampleContent(coord + float2(-r, -r)) * 0.07511;
    return result;
}

half4 main(float2 coord) {
    float2 halfSize = size * 0.5;
    float2 centeredCoord = coord - halfSize;
    float radius = radiusAt(centeredCoord, cornerRadii);
    float sd = sdRoundedRect(centeredCoord, halfSize, radius);
    if (-sd >= refractionHeight) return blurredContent(coord);

    sd = min(sd, 0.0);
    float d = circleMap(1.0 - -sd / refractionHeight) * refractionAmount;
    float gradRadius = min(max(radius * 1.5, 30.0), min(halfSize.x, halfSize.y));
    float2 grad = safeNormalize(gradRoundedRect(centeredCoord, halfSize, gradRadius), float2(0.0, -1.0));
    float2 refractedCoord = coord + d * grad;
    float dispersionFactor = chromaticAberration * ((centeredCoord.x * centeredCoord.y) / max(1.0, halfSize.x * halfSize.y));
    float2 dispersedCoord = d * grad * dispersionFactor;

    half4 color;
    color.r = blurredContent(refractedCoord + dispersedCoord).r;
    color.g = blurredContent(refractedCoord).g;
    color.b = blurredContent(refractedCoord - dispersedCoord).b;
    color.a = blurredContent(refractedCoord).a;
    return color;
}
`;

export interface LiquidUniformInput {
  /** 画布尺寸（canvas 逻辑坐标）。 */
  width: number;
  height: number;
  /** 圆角（canvas 单位）。 */
  cornerRadius: number;
  /** 折射高度（canvas 单位）。 */
  refractionHeight: number;
  /** 折射偏移（canvas 单位）；与 AGSL 一致，shader 内取负值。 */
  refractionOffset: number;
  /** 色散系数 0-1。 */
  dispersion: number;
  /** 模糊半径（content 单位），shader 内按 contentScale 换算。 */
  blurRadius: number;
  /** 玻璃区域相对快照区域左上角的偏移（content 单位）。 */
  sourceOffsetX: number;
  sourceOffsetY: number;
  /** 快照到 canvas 的有效采样比例（含 Android 的像素密度）。 */
  contentScale: number;
}

export type LiquidUniforms = Record<string, number | number[]>;

/** 组装的 uniform 键必须与 SkSL 声明一一对应（RN Skia 按名绑定）。 */
export function buildLiquidUniforms(input: LiquidUniformInput): LiquidUniforms {
  return {
    size: [input.width, input.height],
    cornerRadii: [input.cornerRadius, input.cornerRadius],
    refractionHeight: input.refractionHeight,
    refractionAmount: -input.refractionOffset,
    chromaticAberration: input.dispersion,
    blurRadius: Math.max(0.01, input.blurRadius * input.contentScale),
    sourceOffset: [input.sourceOffsetX, input.sourceOffsetY],
    contentScale: input.contentScale,
  };
}
