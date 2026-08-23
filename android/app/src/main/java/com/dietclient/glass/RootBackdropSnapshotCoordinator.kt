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
 * 不能把根视图录制为 RenderNode：玻璃宿主本身是根视图的后代，会造成 display list 环。
 * 本协调器只输出 Bitmap；宿主（AndroidGlassSurface / SkiaGlassSurface）随后自行消费。
 *
 * 性能策略（对应 BLASTBufferQueue 缓冲饱和问题的修复）：
 * - 捕获按 captureScale 降采样（默认 0.5x），软件光栅化与纹理上传成本降为 1/4；
 * - 区域与像素未变时（sameAs 去重）保留旧快照，避免轮换 bitmap 触发无意义失效；
 * - 捕获冷却按上次耗时自适应（fast/slow 两档）。
 */
/**
 * 捕获协调器入口公开（应用模块内部机械，无泄漏风险）：
 * Kotlin 接口成员不允许 internal 修饰、public override 又不能引用 internal 签名类型，
 * 因此契约（接口 + 快照数据类 + 协调器）整体保持 public；
 * 策略类（RootBackdropSnapshotPolicy 等）仍为 internal，不进任何公开签名。
 */
object RootBackdropSnapshotCoordinator {
  private const val debugTag = "LiquidGlassSnapshot"
  private val coordinators = WeakHashMap<View, Coordinator>()
  private val debugStats = mutableMapOf<String, DebugStats>()

  fun register(host: BackdropSnapshotHost, root: View) {
    checkMainThread()
    val coordinator = coordinators.getOrPut(root) { Coordinator(root) }
    coordinator.add(host)
  }

  fun unregister(host: BackdropSnapshotHost, root: View?) {
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
      "玻璃快照只能在主线程更新"
    }
  }

  private class Coordinator(private val root: View) {
    private val hosts = Collections.newSetFromMap(WeakHashMap<BackdropSnapshotHost, Boolean>())
    private val groups = mutableMapOf<String, GroupState>()
    private var listenerAdded = false

    private val preDrawListener = ViewTreeObserver.OnPreDrawListener {
      captureRequestedGroups()
      true
    }

    fun add(host: BackdropSnapshotHost) {
      hosts.add(host)
      if (!listenerAdded && root.viewTreeObserver.isAlive) {
        root.viewTreeObserver.addOnPreDrawListener(preDrawListener)
        listenerAdded = true
      }
    }

    fun remove(host: BackdropSnapshotHost) {
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
        // 降采样：快照 Bitmap 按 captureScale 缩小，软件光栅化像素数与纹理上传带宽降为 1/4。
        val scale = RootBackdropSnapshotPolicy.captureScale
        val bitmapWidth = RootBackdropSnapshotPolicy.downscaledSize(rect.width(), scale)
        val bitmapHeight = RootBackdropSnapshotPolicy.downscaledSize(rect.height(), scale)
        val bitmap = state.obtainBitmap(bitmapWidth, bitmapHeight)
        val startedAt = SystemClock.uptimeMillis()
        Canvas(bitmap).apply {
          drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
          val saveCount = save()
          try {
            clipRect(0, 0, bitmap.width, bitmap.height)
            // 先 scale 再 translate：captureRect 的 root 坐标经矩阵映射到整个缩小后的 Bitmap。
            scale(scale, scale)
            translate(-rect.left.toFloat(), -rect.top.toFloat())
            // root.draw() 在 Fabric 下可能复用子视图上一帧的硬件显示列表；仅在
            // draw() 中短路不足以保证跳过玻璃。同步隐藏所有已注册宿主，确保当前
            // 快照不会包含任一导航层或弹层自身，再由 finally 恢复可见性。
            val excludedHosts = hosts.filterIsInstance<BackdropCaptureExcludable>()
            BackdropCaptureGate.withExcludedHosts(excludedHosts) {
              root.draw(this)
            }
          } finally {
            restoreToCount(saveCount)
          }
        }
        val elapsed = SystemClock.uptimeMillis() - startedAt

        // 内容去重：区域与像素都未变化时保留旧快照，不轮换 bitmap、不触发失效，
        // 打破「捕获 -> acceptRootSnapshot -> invalidate -> 再捕获」的放大回路。
        // 同时延长冷却：否则活动期间 pre-draw 每帧触发，会退化为每帧重复光栅化。
        val prev = state.snapshot
        if (prev != null && state.rect == rect &&
          prev.bitmap.width == bitmap.width && prev.bitmap.height == bitmap.height &&
          bitmap.sameAs(prev.bitmap)
        ) {
          state.nextCaptureAtMs = now + RootBackdropSnapshotPolicy.nextIntervalMs(elapsed)
          return
        }

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
      // 按降采样后的实际 Bitmap 尺寸核算，与 capture() 保持一致。
      val scaled = { w: Int, h: Int ->
        bytesFor(
          RootBackdropSnapshotPolicy.downscaledSize(w),
          RootBackdropSnapshotPolicy.downscaledSize(h),
        )
      }
      val bytes = scaled(rect.width(), rect.height())
      if (bytes > RootBackdropSnapshotPolicy.maxGroupBytes) return true
      var total = 0L
      requests.forEach { (group, groupRequests) ->
        val requestRect = if (group == currentGroup) rect else union(groupRequests.map { it.captureRect }, root.width, root.height)
        if (requestRect != null) total += scaled(requestRect.width(), requestRect.height()) * RootBackdropSnapshotPolicy.bufferCount
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

  data class SnapshotRequest(
    val host: BackdropSnapshotHost,
    val group: String,
    val captureRect: Rect,
  )

  data class RootSnapshot(
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

/**
 * 玻璃宿主参与背景捕获的契约。
 * 由 RootBackdropSnapshotCoordinator 在 pre-draw 回调，宿主消费快照后自行渲染或上报。
 * 接口成员隐式 public（Kotlin 不允许接口内 internal），实现类必须用 public override。
 */
interface BackdropSnapshotHost {
  /** 当前帧是否需要捕获；返回 null 表示不需要（如离屏/未激活）。 */
  fun snapshotRequest(root: View, rootLocation: IntArray): RootBackdropSnapshotCoordinator.SnapshotRequest?

  /** 接收新快照（含版本与区域信息）。 */
  fun acceptRootSnapshot(snapshot: RootBackdropSnapshotCoordinator.RootSnapshot, rootLocation: IntArray)

  /** 快照失效（区域变化/注销/内存超限）。 */
  fun clearRootSnapshot()
}
