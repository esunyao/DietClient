package com.dietclient.glass

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.PorterDuff
import android.graphics.Rect
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.view.ViewTreeObserver
import com.dietclient.BuildConfig
import java.util.Collections
import java.util.WeakHashMap

/**
 * 将 React 根视图的一小块区域光栅化为真实像素。
 *
 * 不能把根视图录制为 RenderNode：液态宿主本身是根视图的后代，会造成 display list 环。
 * 本协调器只输出 Bitmap；液态表面随后把 BitmapShader 作为 RuntimeShader 输入使用。
 */
internal object RootBackdropSnapshotCoordinator {
  private const val debugTag = "LiquidGlassSnapshot"
  private val coordinators = WeakHashMap<View, Coordinator>()
  private val debugStats = mutableMapOf<String, DebugStats>()

  fun register(host: AndroidGlassSurface, root: View) {
    checkMainThread()
    val coordinator = coordinators.getOrPut(root) { Coordinator(root) }
    coordinator.add(host)
  }

  fun unregister(host: AndroidGlassSurface, root: View?) {
    checkMainThread()
    val coordinator = root?.let { coordinators[it] } ?: return
    coordinator.remove(host)
    if (coordinator.isEmpty()) coordinators.remove(root)
  }

  fun recordInvalidation(group: String) {
    if (!BuildConfig.DEBUG) return
    val stats = debugStats.getOrPut(group) { DebugStats() }
    stats.invalidations++
    logStats(group, stats)
  }

  private fun recordCapture(group: String, elapsedMs: Long, bitmapSlot: Int) {
    if (!BuildConfig.DEBUG) return
    val stats = debugStats.getOrPut(group) { DebugStats() }
    stats.captures++
    stats.lastCaptureMs = elapsedMs
    stats.bitmapSlot = bitmapSlot
    logStats(group, stats)
  }

  private fun logStats(group: String, stats: DebugStats) {
    val now = SystemClock.uptimeMillis()
    if (now - stats.lastLogAtMs < 1000L) return
    stats.lastLogAtMs = now
    Log.d(debugTag, "group=$group captures=${stats.captures} invalidations=${stats.invalidations} captureMs=${stats.lastCaptureMs} bitmapSlot=${stats.bitmapSlot}")
  }

  private fun checkMainThread() {
    check(android.os.Looper.myLooper() == android.os.Looper.getMainLooper()) {
      "液态玻璃快照只能在主线程更新"
    }
  }

  private class Coordinator(private val root: View) {
    private val hosts = Collections.newSetFromMap(WeakHashMap<AndroidGlassSurface, Boolean>())
    private val groups = mutableMapOf<String, GroupState>()
    private var listenerAdded = false

    private val preDrawListener = ViewTreeObserver.OnPreDrawListener {
      captureRequestedGroups()
      true
    }

    fun add(host: AndroidGlassSurface) {
      hosts.add(host)
      if (!listenerAdded && root.viewTreeObserver.isAlive) {
        root.viewTreeObserver.addOnPreDrawListener(preDrawListener)
        listenerAdded = true
      }
    }

    fun remove(host: AndroidGlassSurface) {
      hosts.remove(host)
      host.clearRootSnapshot()
      if (hosts.isEmpty()) release()
    }

    fun isEmpty(): Boolean = hosts.isEmpty()

    private fun release() {
      if (listenerAdded && root.viewTreeObserver.isAlive) {
        root.viewTreeObserver.removeOnPreDrawListener(preDrawListener)
      }
      listenerAdded = false
      groups.clear()
    }

    private fun captureRequestedGroups() {
      if (!root.isAttachedToWindow || root.width <= 0 || root.height <= 0) {
        hosts.forEach { it.clearRootSnapshot() }
        return
      }

      val rootLocation = IntArray(2)
      root.getLocationInWindow(rootLocation)
      val requests = hosts.mapNotNull { it.snapshotRequest(root, rootLocation) }.groupBy { it.group }
      groups.keys.minus(requests.keys).forEach { groups.remove(it) }

      requests.forEach { (group, groupRequests) ->
        val requestedRect = union(groupRequests.map { it.captureRect }, root.width, root.height)
        if (requestedRect == null || exceedsMemoryBudget(requestedRect, group, requests)) {
          groupRequests.forEach { it.host.clearRootSnapshot() }
          return@forEach
        }

        val state = groups.getOrPut(group) { GroupState() }
        val now = SystemClock.uptimeMillis()
        val canReuse = state.snapshot != null && state.rect.contains(requestedRect)
        val captureDue = !canReuse || now >= state.nextCaptureAtMs
        if (captureDue) {
          capture(group, requestedRect, state, now)
        }

        val snapshot = state.snapshot
        if (snapshot != null && state.rect.contains(requestedRect)) {
          groupRequests.forEach { it.host.acceptRootSnapshot(snapshot, rootLocation) }
        } else {
          groupRequests.forEach { it.host.clearRootSnapshot() }
        }
      }
    }

    private fun capture(group: String, rect: Rect, state: GroupState, now: Long) {
      try {
        val bitmap = state.obtainBitmap(rect.width(), rect.height())
        val startedAt = SystemClock.uptimeMillis()
        Canvas(bitmap).apply {
          drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
          val saveCount = save()
          try {
            clipRect(0, 0, bitmap.width, bitmap.height)
            translate(-rect.left.toFloat(), -rect.top.toFloat())
            AndroidGlassSurface.beginRootBitmapCapture()
            try {
              root.draw(this)
            } finally {
              AndroidGlassSurface.endRootBitmapCapture()
            }
          } finally {
            restoreToCount(saveCount)
          }
        }
        val elapsed = SystemClock.uptimeMillis() - startedAt
        state.rect.set(rect)
        state.snapshot = RootSnapshot(bitmap, Rect(rect), ++state.version)
        state.nextCaptureAtMs = now + RootBackdropSnapshotPolicy.nextIntervalMs(elapsed)
        recordCapture(group, elapsed, state.lastBitmapSlot)
      } catch (_: OutOfMemoryError) {
        state.snapshot = null
      } catch (_: RuntimeException) {
        state.snapshot = null
      }
    }

    private fun exceedsMemoryBudget(rect: Rect, currentGroup: String, requests: Map<String, List<SnapshotRequest>>): Boolean {
      val bytes = bytesFor(rect.width(), rect.height())
      if (bytes > RootBackdropSnapshotPolicy.maxGroupBytes) return true
      var total = 0L
      requests.forEach { (group, groupRequests) ->
        val requestRect = if (group == currentGroup) rect else union(groupRequests.map { it.captureRect }, root.width, root.height)
        if (requestRect != null) total += bytesFor(requestRect.width(), requestRect.height()) * RootBackdropSnapshotPolicy.bufferCount
      }
      return !RootBackdropSnapshotPolicy.fitsMemoryBudget(bytes, total)
    }

    private fun union(rects: List<Rect>, maxWidth: Int, maxHeight: Int): Rect? {
      if (rects.isEmpty()) return null
      val union = Rect(rects.first())
      rects.drop(1).forEach { union.union(it) }
      if (!union.intersect(0, 0, maxWidth, maxHeight) || union.isEmpty) return null
      return union
    }
  }

  internal data class SnapshotRequest(
    val host: AndroidGlassSurface,
    val group: String,
    val captureRect: Rect,
  )

  internal data class RootSnapshot(
    val bitmap: Bitmap,
    val rect: Rect,
    val version: Long,
  )

  private class GroupState {
    val rect = Rect()
    private val bitmaps = mutableListOf<Bitmap>()
    private var nextBitmap = 0
    var snapshot: RootSnapshot? = null
    var version = 0L
    var nextCaptureAtMs = 0L

    fun obtainBitmap(width: Int, height: Int): Bitmap {
      if (bitmaps.any { it.width != width || it.height != height }) {
        // 不调用 recycle()：上一帧可能仍被硬件管线读取，交给 GC 在安全时机回收。
        bitmaps.clear()
        nextBitmap = 0
      }
      if (bitmaps.size < RootBackdropSnapshotPolicy.bufferCount) {
        bitmaps += Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
      }
      lastBitmapSlot = nextBitmap
      val bitmap = bitmaps[nextBitmap]
      nextBitmap = (nextBitmap + 1) % bitmaps.size
      return bitmap
    }

    var lastBitmapSlot = -1
  }

  private class DebugStats {
    var captures = 0L
    var invalidations = 0L
    var lastCaptureMs = 0L
    var bitmapSlot = -1
    var lastLogAtMs = 0L
  }

  private fun bytesFor(width: Int, height: Int): Long = width.toLong() * height.toLong() * 4L
}
