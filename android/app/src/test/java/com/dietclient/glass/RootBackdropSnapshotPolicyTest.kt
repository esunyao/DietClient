package com.dietclient.glass

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

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
}
