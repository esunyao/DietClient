export type SnapshotFrameInput = {
  width: number;
  height: number;
  sourceOffsetX: number;
  sourceOffsetY: number;
  contentScale: number;
  canvasWidth: number;
  canvasHeight: number;
};

export type SnapshotDrawFrame = {
  x: number;
  y: number;
  width: number;
  height: number;
};

/** 原生快照的物理像素坐标，换算为 Skia/RN 的逻辑像素坐标。 */
export type NativeSnapshotCoordinates = Pick<
  SnapshotFrameInput,
  'width' | 'height' | 'sourceOffsetX' | 'sourceOffsetY' | 'contentScale'
>;

/**
 * 原生 Android 捕获区和 JPEG 位图都以物理 px 上报，React Native Skia 的绘制坐标
 * 则与 onLayout 一样使用 dp。contentScale 同时包含捕获降采样和物理 px → dp 的换算；
 * sourceOffset 只需除以设备像素比即可回到 canvas 坐标。
 */
export function normalizeNativeSnapshotCoordinates(
  input: NativeSnapshotCoordinates,
  pixelRatio: number,
): NativeSnapshotCoordinates | null {
  const values = [
    input.width,
    input.height,
    input.sourceOffsetX,
    input.sourceOffsetY,
    input.contentScale,
    pixelRatio,
  ];
  if (values.some(value => !Number.isFinite(value)) || pixelRatio <= 0) return null;

  return {
    width: input.width,
    height: input.height,
    sourceOffsetX: input.sourceOffsetX / pixelRatio,
    sourceOffsetY: input.sourceOffsetY / pixelRatio,
    contentScale: input.contentScale * pixelRatio,
  };
}

/**
 * 将原生快照像素映射到 Skia canvas 的内容坐标。
 * 调用方必须先将原生快照换算为 canvas 的逻辑坐标；二者再通过 contentScale 归一化。
 * 坐标越界时返回 null，让上层使用实体材质而不是绘制残留快照。
 *
 * maxSourceOffset 用于拒绝"陈旧帧"：非液态玻璃的捕获区与自身区域严格重合
 * （sourceOffset ≈ 0）；玻璃移动后若位图未同步重捕获，偏移会超出容差，
 * 继续绘制会把上一帧内容以残影画进玻璃内部（玻璃左侧显示不全的根因）。
 */
export function normalizeSnapshotFrame(
  input: SnapshotFrameInput,
  maxSourceOffset = Number.POSITIVE_INFINITY,
): SnapshotDrawFrame | null {
  const values = [
    input.width,
    input.height,
    input.sourceOffsetX,
    input.sourceOffsetY,
    input.contentScale,
    input.canvasWidth,
    input.canvasHeight,
  ];
  if (values.some(value => !Number.isFinite(value))) return null;
  if (input.width <= 0 || input.height <= 0 || input.contentScale <= 0) return null;
  if (input.canvasWidth <= 0 || input.canvasHeight <= 0) return null;

  // 陈旧帧守卫：偏移超过容差说明快照捕获区与玻璃当前区域不一致，拒绝绘制残留。
  if (
    Math.abs(input.sourceOffsetX) > maxSourceOffset ||
    Math.abs(input.sourceOffsetY) > maxSourceOffset
  ) {
    return null;
  }

  const frame = {
    // `|| 0` 归一化 -0，避免绘制与测试中的严格相等歧义。
    x: -input.sourceOffsetX || 0,
    y: -input.sourceOffsetY || 0,
    width: input.width / input.contentScale,
    height: input.height / input.contentScale,
  };

  // 允许液态快照在玻璃外有采样边缘，但拒绝完全脱离 canvas 的异常帧。
  const intersectsCanvas =
    frame.x < input.canvasWidth &&
    frame.y < input.canvasHeight &&
    frame.x + frame.width > 0 &&
    frame.y + frame.height > 0;
  return intersectsCanvas ? frame : null;
}
