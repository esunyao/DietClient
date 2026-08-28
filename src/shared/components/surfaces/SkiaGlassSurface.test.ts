import {
  GLASS_LOOKS,
  LIQUID_BASE_FILL,
  LIQUID_OVERLAY_FILL,
  OPAQUE_FALLBACK_FILL,
  blurRadiusForIntensity,
  glowRadiusForSize,
} from './SkiaGlassSurfaceLook';
import {
  LIQUID_GLASS_SKSL,
  buildLiquidUniforms,
  type LiquidUniformInput,
} from './SkiaGlassSurfaceShader';
import {
  normalizeNativeSnapshotCoordinates,
  normalizeSnapshotFrame,
} from './SkiaGlassSnapshotFrame';

const baseInput: LiquidUniformInput = {
  width: 360,
  height: 120,
  cornerRadius: 26,
  refractionHeight: 21,
  refractionOffset: 60,
  dispersion: 0.8,
  blurRadius: 10,
  sourceOffsetX: 40,
  sourceOffsetY: 12,
  contentScale: 0.5,
};

describe('SkiaGlassSurfaceLook', () => {
  it('soft 变体不参与背景捕获（零成本）', () => {
    expect(GLASS_LOOKS.soft.needsCapture).toBe(false);
    expect(GLASS_LOOKS.soft.overlay).toBeNull();
  });

  it('frosted 与 navigation 参与背景捕获', () => {
    expect(GLASS_LOOKS.frosted.needsCapture).toBe(true);
    expect(GLASS_LOOKS.navigation.needsCapture).toBe(true);
  });

  it('intensity 映射为确定的正模糊半径', () => {
    expect(blurRadiusForIntensity(50)).toBe(12.5);
    expect(blurRadiusForIntensity(0)).toBe(0);
    expect(blurRadiusForIntensity(-10)).toBe(0);
  });

  it('触摸光晕半径随尺寸增长（对齐原生 max(w,h)*0.55）', () => {
    expect(glowRadiusForSize(360, 120)).toBeCloseTo(198);
    expect(glowRadiusForSize(120, 360)).toBeCloseTo(198);
  });

  it('液态与兜底色为常量（供视觉回归参照）', () => {
    expect(LIQUID_BASE_FILL).toBe('rgba(255, 255, 255, 0.70)');
    expect(LIQUID_OVERLAY_FILL).toBe('rgba(255, 255, 255, 0.12)');
    expect(OPAQUE_FALLBACK_FILL).toBe('#FFFFFF');
  });
});

describe('buildLiquidUniforms', () => {
  it('uniform 键与 SkSL 声明一一对应', () => {
    const uniforms = buildLiquidUniforms(baseInput);
    const declared = [
      'size',
      'cornerRadii',
      'refractionHeight',
      'refractionAmount',
      'chromaticAberration',
      'blurRadius',
      'sourceOffset',
      'contentScale',
    ];
    for (const key of declared) {
      expect(Object.prototype.hasOwnProperty.call(uniforms, key)).toBe(true);
    }
    expect(LIQUID_GLASS_SKSL).toContain('uniform shader content;');
  });

  it('折射偏移取负值（与 AGSL native 约定一致）', () => {
    const uniforms = buildLiquidUniforms(baseInput);
    expect(uniforms.refractionAmount).toBe(-60);
    expect(uniforms.refractionHeight).toBe(21);
  });

  it('blurRadius 按 contentScale 换算为快照像素半径', () => {
    const uniforms = buildLiquidUniforms(baseInput);
    expect(uniforms.blurRadius).toBe(5);
    expect(uniforms.blurRadius).toBeGreaterThanOrEqual(0.01);
  });

  it('sourceOffset 原样透传（坐标换算在 shader 内完成）', () => {
    const uniforms = buildLiquidUniforms(baseInput);
    expect(uniforms.sourceOffset).toEqual([40, 12]);
    expect(uniforms.contentScale).toBe(0.5);
  });

  it('高密度 Android 快照以 dp 几何和物理像素采样率共同驱动 shader', () => {
    const snapshot = normalizeNativeSnapshotCoordinates(
      {
        width: 588,
        height: 91,
        sourceOffsetX: 35,
        sourceOffsetY: 17.5,
        contentScale: 0.5,
      },
      3.5,
    );
    expect(snapshot).not.toBeNull();

    const uniforms = buildLiquidUniforms({
      width: 336,
      height: 52,
      cornerRadius: 20,
      refractionHeight: 20,
      refractionOffset: 70,
      dispersion: 0.5,
      // 原生 10px 模糊半径先换算为 10 / 3.5 dp。
      blurRadius: 10 / 3.5,
      sourceOffsetX: snapshot!.sourceOffsetX,
      sourceOffsetY: snapshot!.sourceOffsetY,
      contentScale: snapshot!.contentScale,
    });

    expect(uniforms.size).toEqual([336, 52]);
    expect(uniforms.cornerRadii).toEqual([20, 20]);
    expect(uniforms.sourceOffset).toEqual([10, 5]);
    expect(uniforms.contentScale).toBe(1.75);
    // (10 / 3.5)dp × (0.5 × 3.5) = 5px，保持原有物理模糊范围。
    expect(uniforms.blurRadius).toBe(5);
  });
});

describe('normalizeSnapshotFrame', () => {
  it('将 3.5x Android 物理快照还原为 dp canvas 坐标', () => {
    const coordinates = normalizeNativeSnapshotCoordinates(
      {
        width: 588,
        height: 91,
        sourceOffsetX: 35,
        sourceOffsetY: 17.5,
        contentScale: 0.5,
      },
      3.5,
    );
    expect(coordinates).toEqual({
      width: 588,
      height: 91,
      sourceOffsetX: 10,
      sourceOffsetY: 5,
      contentScale: 1.75,
    });
    expect(
      normalizeSnapshotFrame({
        ...coordinates!,
        canvasWidth: 336,
        canvasHeight: 52,
      }),
    ).toEqual({ x: -10, y: -5, width: 336, height: 52 });
  });

  it('拒绝无效设备像素比，避免将异常原生快照画进 canvas', () => {
    expect(
      normalizeNativeSnapshotCoordinates(
        {
          width: 300,
          height: 100,
          sourceOffsetX: 0,
          sourceOffsetY: 0,
          contentScale: 0.5,
        },
        0,
      ),
    ).toBeNull();
  });

  it('按 contentScale 将像素快照映射回 canvas 坐标', () => {
    expect(
      normalizeSnapshotFrame({
        width: 300,
        height: 100,
        sourceOffsetX: 40,
        sourceOffsetY: 12,
        contentScale: 0.5,
        canvasWidth: 360,
        canvasHeight: 120,
      }),
    ).toEqual({ x: -40, y: -12, width: 600, height: 200 });
  });

  it('拒绝完全脱离 canvas 或无效缩放的快照', () => {
    expect(
      normalizeSnapshotFrame({
        width: 80,
        height: 40,
        sourceOffsetX: 500,
        sourceOffsetY: 0,
        contentScale: 0.5,
        canvasWidth: 360,
        canvasHeight: 120,
      }),
    ).toBeNull();
    expect(
      normalizeSnapshotFrame({
        width: 80,
        height: 40,
        sourceOffsetX: 0,
        sourceOffsetY: 0,
        contentScale: 0,
        canvasWidth: 360,
        canvasHeight: 120,
      }),
    ).toBeNull();
  });

  it('非液态玻璃拒绝偏移超容差的陈旧快照（防止残影）', () => {
    const base = {
      width: 300,
      height: 100,
      sourceOffsetX: 0,
      sourceOffsetY: 0,
      contentScale: 0.5,
      canvasWidth: 360,
      canvasHeight: 120,
    };
    // 捕获区与玻璃区域重合：正常绘制
    expect(normalizeSnapshotFrame(base, 1)).toEqual({ x: 0, y: 0, width: 600, height: 200 });
    // 玻璃移动后旧位图以新偏移投递（tabbar translateY 显隐等）→ 拒绝绘制残留
    expect(normalizeSnapshotFrame({ ...base, sourceOffsetX: 66, sourceOffsetY: 66 }, 1)).toBeNull();
    expect(
      normalizeSnapshotFrame({ ...base, sourceOffsetX: -30, sourceOffsetY: 12 }, 1),
    ).toBeNull();
    // 1px 容差内的亚像素抖动仍可接受
    expect(
      normalizeSnapshotFrame({ ...base, sourceOffsetX: 0.5, sourceOffsetY: -0.5 }, 1),
    ).not.toBeNull();
  });

  it('液态模式允许捕获区外扩，但偏移超上限时仍拒绝陈旧帧', () => {
    const base = {
      width: 300,
      height: 100,
      sourceOffsetX: 40,
      sourceOffsetY: 12,
      contentScale: 0.5,
      canvasWidth: 360,
      canvasHeight: 120,
    };
    // 液态 padding 上限内的偏移合法（折射采样边缘）
    expect(normalizeSnapshotFrame(base, 50)).toEqual({ x: -40, y: -12, width: 600, height: 200 });
    // 超出 padding 上限 → 视为陈旧帧
    expect(
      normalizeSnapshotFrame({ ...base, sourceOffsetX: 200, sourceOffsetY: 200 }, 50),
    ).toBeNull();
  });

  it('未指定 maxSourceOffset 时保持原行为（兼容旧调用）', () => {
    expect(
      normalizeSnapshotFrame({
        width: 300,
        height: 100,
        sourceOffsetX: 40,
        sourceOffsetY: 12,
        contentScale: 0.5,
        canvasWidth: 360,
        canvasHeight: 120,
      }),
    ).toEqual({ x: -40, y: -12, width: 600, height: 200 });
  });
});
