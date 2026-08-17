package com.dietclient.glass

/** 液态玻璃参数边界：布局参数按 dp 转 px，模糊半径保持物理像素。 */
internal object LiquidGlassParameterPolicy {
  fun supportsLiquidGlass(sdkInt: Int): Boolean = sdkInt >= 33

  fun cornerRadiusPx(density: Float, value: Double, height: Int): Float {
    val radius = (value.coerceAtLeast(0.0) * density).toFloat()
    return if (height > 0) radius.coerceAtMost(height / 2f) else radius
  }

  fun refractionHeightPx(density: Float, value: Double): Float =
    (value.coerceIn(12.0, 50.0) * density).toFloat()

  fun refractionOffsetPx(density: Float, value: Double): Float =
    (value.coerceIn(20.0, 120.0) * density).toFloat()

  fun blurRadiusPx(value: Double): Float = value.coerceIn(0.01, 50.0).toFloat()

  fun dispersion(value: Double): Float = value.coerceIn(0.0, 1.0).toFloat()
}

/** 根视图像素采样的纯策略，方便在 JVM 单测中覆盖内存与节流边界。 */
internal object RootBackdropSnapshotPolicy {
  const val maxGroupBytes = 12 * 1024 * 1024
  const val maxTotalBytes = 24 * 1024 * 1024
  const val bufferCount = 2
  const val fastIntervalMs = 50L
  const val slowIntervalMs = 83L
  const val slowCaptureMs = 8L

  fun capturePaddingPx(refractionHeightPx: Float, refractionOffsetPx: Float, blurRadiusPx: Float, density: Float): Int =
    kotlin.math.ceil(kotlin.math.max(refractionHeightPx, refractionOffsetPx) + blurRadiusPx * 2f + density * 4f).toInt()

  fun fitsMemoryBudget(groupBytes: Long, totalSnapshotBytes: Long): Boolean =
    groupBytes <= maxGroupBytes && totalSnapshotBytes <= maxTotalBytes

  fun nextIntervalMs(captureElapsedMs: Long): Long =
    if (captureElapsedMs > slowCaptureMs) slowIntervalMs else fastIntervalMs

  fun needsSnapshotInvalidation(
    hasSnapshot: Boolean,
    versionChanged: Boolean,
    bitmapChanged: Boolean,
    offsetChanged: Boolean,
  ): Boolean = !hasSnapshot || versionChanged || bitmapChanged || offsetChanged

  fun needsSnapshotClear(hasSnapshot: Boolean, hasBitmapShader: Boolean): Boolean =
    hasSnapshot || hasBitmapShader
}
