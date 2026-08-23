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

/**
 * 将原生快照像素映射到 Skia canvas 的内容坐标。
 * iOS 使用 points、Android 使用 px，但二者都通过 contentScale 归一化到同一公式。
 * 坐标越界时返回 null，让上层使用实体材质而不是绘制残留快照。
 */
export function normalizeSnapshotFrame(input: SnapshotFrameInput): SnapshotDrawFrame | null {
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

  const frame = {
    x: -input.sourceOffsetX,
    y: -input.sourceOffsetY,
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
