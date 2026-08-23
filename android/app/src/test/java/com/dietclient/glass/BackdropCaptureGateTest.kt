package com.dietclient.glass

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BackdropCaptureGateTest {
  @Test
  fun excludesHostsBeforeCaptureAndRestoresThemAfterward() {
    val events = mutableListOf<String>()
    val header = FakeHost("header", true, events)
    val tab = FakeHost("tab", true, events)

    BackdropCaptureGate.withExcludedHosts(listOf(header, tab)) {
      assertTrue(BackdropCaptureGate.isActive())
      assertFalse(header.visible)
      assertFalse(tab.visible)
      events += "draw"
    }

    assertEquals(listOf("header:true", "tab:true", "draw", "tab:false", "header:false"), events)
    assertTrue(header.visible)
    assertTrue(tab.visible)
    assertFalse(BackdropCaptureGate.isActive())
  }

  @Test
  fun restoresOriginalInvisibleStateWhenCaptureThrows() {
    val host = FakeHost("sheet", false, mutableListOf())

    try {
      BackdropCaptureGate.withExcludedHosts(listOf(host)) {
        throw IllegalStateException("capture failed")
      }
    } catch (_: IllegalStateException) {
      // 预期异常；断言 finally 仍已恢复原始状态。
    }

    assertFalse(host.visible)
    assertEquals(listOf(true, false), host.transitions)
    assertFalse(BackdropCaptureGate.isActive())
  }

  @Test
  fun nestedCaptureDoesNotRestoreAnOuterHostEarly() {
    val events = mutableListOf<String>()
    val header = FakeHost("header", true, events)
    val tab = FakeHost("tab", true, events)

    BackdropCaptureGate.withExcludedHosts(listOf(header)) {
      BackdropCaptureGate.withExcludedHosts(listOf(header, tab)) {
        assertFalse(header.visible)
        assertFalse(tab.visible)
      }
      assertFalse(header.visible)
      assertTrue(tab.visible)
    }

    assertEquals(listOf(true, false), header.transitions)
    assertEquals(listOf(true, false), tab.transitions)
    assertFalse(BackdropCaptureGate.isActive())
  }

  private class FakeHost(
    private val name: String,
    initialVisibility: Boolean,
    private val events: MutableList<String>,
  ) : BackdropCaptureExcludable {
    var visible = initialVisibility
    val transitions = mutableListOf<Boolean>()
    private var visibilityBeforeExclusion = initialVisibility

    override fun setExcludedFromBackdropCapture(excluded: Boolean) {
      transitions += excluded
      events += "$name:$excluded"
      if (excluded) {
        visibilityBeforeExclusion = visible
        visible = false
      } else {
        visible = visibilityBeforeExclusion
      }
    }
  }
}
