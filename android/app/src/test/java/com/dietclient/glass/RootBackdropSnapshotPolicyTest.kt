package com.dietclient.glass

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

/** RootBackdropSnapshotPolicy 纯策略：降采样尺寸、捕获节流。 */
class RootBackdropSnapshotPolicyTest {
  @Test
  fun downscalesSizesWithCeilingAndMinimum() {
    assertEquals(50, RootBackdropSnapshotPolicy.downscaledSize(100, 0.5f))
    assertEquals(51, RootBackdropSnapshotPolicy.downscaledSize(101, 0.5f))
    assertEquals(1, RootBackdropSnapshotPolicy.downscaledSize(1, 0.5f))
    assertEquals(1, RootBackdropSnapshotPolicy.downscaledSize(0, 0.5f))
    assertEquals(100, RootBackdropSnapshotPolicy.downscaledSize(100, 1f))
  }

  @Test
  fun captureScaleStaysWithinSafeRange() {
    assertTrue(RootBackdropSnapshotPolicy.captureScale > 0f)
    assertTrue(RootBackdropSnapshotPolicy.captureScale <= 1f)
  }

  @Test
  fun refreshIntervalsStayMonotonicWithCaptureCost() {
    assertEquals(
      RootBackdropSnapshotPolicy.fastIntervalMs,
      RootBackdropSnapshotPolicy.nextIntervalMs(RootBackdropSnapshotPolicy.slowCaptureMs),
    )
    assertEquals(
      RootBackdropSnapshotPolicy.slowIntervalMs,
      RootBackdropSnapshotPolicy.nextIntervalMs(RootBackdropSnapshotPolicy.slowCaptureMs + 1),
    )
    assertTrue(RootBackdropSnapshotPolicy.slowIntervalMs >= RootBackdropSnapshotPolicy.fastIntervalMs)
  }

  @Test
  fun staleOffsetToleranceRejectsMovedGlassButKeepsSubPixelJitter() {
    val tolerance = RootBackdropSnapshotPolicy.snapshotOffsetTolerancePx
    assertTrue(tolerance > 0f)
    assertTrue(tolerance <= 1f)
    // 玻璃移动（如 tabbar translateY 显隐）后旧位图被以新偏移投递 → 陈旧
    assertTrue(abs(66f - 0f) > tolerance)
    assertTrue(abs(-30f - 0f) > tolerance)
    // 亚像素抖动仍可接受
    assertFalse(abs(0.5f - 0f) > tolerance)
    assertFalse(abs(-0.5f - 0f) > tolerance)
  }

  @Test
  fun forceRecaptureIntervalThrottlesAnimationFrames() {
    assertTrue(RootBackdropSnapshotPolicy.forceRecaptureMinIntervalMs > 0L)
    assertTrue(
      RootBackdropSnapshotPolicy.forceRecaptureMinIntervalMs <=
        RootBackdropSnapshotPolicy.fastIntervalMs,
    )
  }
}
