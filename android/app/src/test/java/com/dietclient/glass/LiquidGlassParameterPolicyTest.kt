package com.dietclient.glass

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LiquidGlassParameterPolicyTest {
  @Test
  fun supportsOnlyAndroid13AndNewer() {
    assertFalse(LiquidGlassParameterPolicy.supportsLiquidGlass(32))
    assertTrue(LiquidGlassParameterPolicy.supportsLiquidGlass(33))
  }

  @Test
  fun convertsLayoutParametersAndClampsTheirRanges() {
    assertEquals(40f, LiquidGlassParameterPolicy.cornerRadiusPx(2f, 40.0, 80), 0.001f)
    assertEquals(24f, LiquidGlassParameterPolicy.refractionHeightPx(2f, 1.0), 0.001f)
    assertEquals(240f, LiquidGlassParameterPolicy.refractionOffsetPx(2f, 200.0), 0.001f)
  }

  @Test
  fun clampsPhysicalBlurAndDispersion() {
    assertEquals(0.01f, LiquidGlassParameterPolicy.blurRadiusPx(0.0), 0.001f)
    assertEquals(50f, LiquidGlassParameterPolicy.blurRadiusPx(99.0), 0.001f)
    assertEquals(0f, LiquidGlassParameterPolicy.dispersion(-1.0), 0.001f)
    assertEquals(1f, LiquidGlassParameterPolicy.dispersion(2.0), 0.001f)
  }

  @Test
  fun calculatesSnapshotPaddingFromTheLargestOpticalDisplacement() {
    assertEquals(244, RootBackdropSnapshotPolicy.capturePaddingPx(73.5f, 210f, 10f, 3.5f))
  }

  @Test
  fun boundsSnapshotMemoryAndReducesRefreshRateAfterSlowCapture() {
    assertTrue(RootBackdropSnapshotPolicy.fitsMemoryBudget(4L * 1024 * 1024, 24L * 1024 * 1024))
    assertFalse(RootBackdropSnapshotPolicy.fitsMemoryBudget(13L * 1024 * 1024, 20L * 1024 * 1024))
    assertFalse(RootBackdropSnapshotPolicy.fitsMemoryBudget(4L * 1024 * 1024, 25L * 1024 * 1024))
    assertEquals(83L, RootBackdropSnapshotPolicy.nextIntervalMs(8L))
    assertEquals(100L, RootBackdropSnapshotPolicy.nextIntervalMs(9L))
  }

  @Test
  fun redrawsOnlyWhenTheDeliveredSnapshotStateChanges() {
    assertFalse(RootBackdropSnapshotPolicy.needsSnapshotInvalidation(true, false, false, false))
    assertTrue(RootBackdropSnapshotPolicy.needsSnapshotInvalidation(false, false, false, false))
    assertTrue(RootBackdropSnapshotPolicy.needsSnapshotInvalidation(true, true, false, false))
    assertTrue(RootBackdropSnapshotPolicy.needsSnapshotInvalidation(true, false, true, false))
    assertTrue(RootBackdropSnapshotPolicy.needsSnapshotInvalidation(true, false, false, true))
  }

  @Test
  fun clearsOnlyWhenThereIsAnActiveSnapshotOrShader() {
    assertFalse(RootBackdropSnapshotPolicy.needsSnapshotClear(false, false))
    assertTrue(RootBackdropSnapshotPolicy.needsSnapshotClear(true, false))
    assertTrue(RootBackdropSnapshotPolicy.needsSnapshotClear(false, true))
  }
}
