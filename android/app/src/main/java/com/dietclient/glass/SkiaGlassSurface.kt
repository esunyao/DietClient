package com.dietclient.glass

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Outline
import android.graphics.Rect
import android.util.Base64
import android.view.View
import android.view.ViewOutlineProvider
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import com.facebook.react.views.view.ReactViewGroup
import java.io.ByteArrayOutputStream
import kotlin.math.abs

/**
 * Skia 玻璃表面（Android）。
 *
 * 本视图 = 玻璃容器本身：圆角裁剪 + 透明底，内部由 JS 挂 Skia Canvas 与业务子节点。
 * 职责限定为背景捕获：
 * 1. 注册到 RootBackdropSnapshotCoordinator，按 pre-draw 节流捕获自身后方区域（0.5x）；
 * 2. 捕获期间 draw() 跳过自身子树（BackdropCaptureGate），避免自捕获反馈；
 * 3. 快照到达后压缩为 JPEG（base64）经 onSnapshot 事件上报 JS，由 Skia 绘制。
 *
 * 事件名遵循 Fabric 约定：JS 侧 onSnapshot ↔ 原生 topSnapshot。
 */
class SkiaGlassSurface(context: Context) : ReactViewGroup(context), BackdropSnapshotHost, BackdropCaptureExcludable {
  private val density = resources.displayMetrics.density
  private val location = IntArray(2)

  private var radiusPx = dp(26.0)
  private var live = false
  private var oneShot = false
  private var liquidEnabled = false
  private var captureGroup = "tab"
  private var refractionHeightPx = dp(20.0)
  private var refractionOffsetPx = dp(70.0)
  private var blurRadiusPx = 10f

  private var source: View? = null
  private var registered = false
  private var hasSnapshot = false
  private var snapshotVersion = -1L
  private var sourceOffsetX = Float.NaN
  private var sourceOffsetY = Float.NaN
  /** 当前已发射快照对应的偏移（发射时记录），用于检测玻璃移动后位图是否已同步重捕获。 */
  private var emittedOffsetX = Float.NaN
  private var emittedOffsetY = Float.NaN
  private var exclusionDepth = 0
  private var visibilityBeforeExclusion = View.VISIBLE

  init {
    setWillNotDraw(false)
    clipToOutline = true
    outlineProvider = object : ViewOutlineProvider() {
      override fun getOutline(view: View, outline: Outline) {
        outline.setRoundRect(0, 0, view.width, view.height, radiusPx)
      }
    }
  }

  // ---------- props ----------

  fun setCornerRadius(value: Double) {
    val nextRadius = LiquidGlassParameterPolicy.cornerRadiusPx(density, value, height)
    if (radiusPx == nextRadius) return
    radiusPx = nextRadius
    invalidateOutline()
  }

  fun setElevated(value: Boolean) {
    elevation = if (value) dp(1.0) else 0f
    translationZ = elevation
  }

  fun setLive(value: Boolean) {
    if (live == value) return
    live = value
    updateRegistration()
  }

  fun setOneShot(value: Boolean) {
    oneShot = value
  }

  fun setLiquidEnabled(value: Boolean) {
    liquidEnabled = value
  }

  fun setLiquidCaptureGroup(value: String?) {
    val nextGroup = if (value == "header") "header" else "tab"
    if (captureGroup == nextGroup) return
    captureGroup = nextGroup
    clearRootSnapshot()
  }

  fun setLiquidRefractionHeight(value: Double) {
    refractionHeightPx = LiquidGlassParameterPolicy.refractionHeightPx(density, value)
  }

  fun setLiquidRefractionOffset(value: Double) {
    refractionOffsetPx = LiquidGlassParameterPolicy.refractionOffsetPx(density, value)
  }

  fun setLiquidBlurRadius(value: Double) {
    blurRadiusPx = LiquidGlassParameterPolicy.blurRadiusPx(value)
  }

  // ---------- 生命周期与捕获 ----------

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    updateRegistration()
  }

  override fun onDetachedFromWindow() {
    unregister()
    super.onDetachedFromWindow()
  }

  override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
    super.onSizeChanged(w, h, oldw, oldh)
    if (h > 0) radiusPx = radiusPx.coerceAtMost(h / 2f)
    if (w != oldw || h != oldh) clearRootSnapshot()
    invalidateOutline()
    updateRegistration()
  }

  override fun draw(canvas: Canvas) {
    // 捕获期间跳过自身子树：快照里玻璃区域保持透明，露出真正的背景内容。
    if (BackdropCaptureGate.isActive()) return
    super.draw(canvas)
  }

  override fun setExcludedFromBackdropCapture(excluded: Boolean) {
    if (excluded) {
      if (exclusionDepth++ == 0) {
        visibilityBeforeExclusion = visibility
        visibility = View.INVISIBLE
      }
      return
    }
    if (exclusionDepth == 0) return
    if (--exclusionDepth == 0) visibility = visibilityBeforeExclusion
  }

  override fun snapshotRequest(root: View, rootLocation: IntArray): RootBackdropSnapshotCoordinator.SnapshotRequest? {
    if (!isCaptureActive() || width <= 0 || height <= 0) return null
    getLocationInWindow(location)
    val left = location[0] - rootLocation[0]
    val top = location[1] - rootLocation[1]
    // 液态折射需要采样玻璃边缘之外的背景：捕获区域按折射参数外扩；
    // 非液态时捕获精确玻璃区域即可（JS 侧按 sourceOffset 1:1 映射）。
    val padding = if (liquidEnabled) {
      RootBackdropSnapshotPolicy.capturePaddingPx(refractionHeightPx, refractionOffsetPx, blurRadiusPx, density)
    } else {
      0
    }
    return RootBackdropSnapshotCoordinator.SnapshotRequest(
      host = this,
      group = captureGroup,
      captureRect = Rect(left - padding, top - padding, left + width + padding, top + height + padding),
    )
  }

  override fun acceptRootSnapshot(snapshot: RootBackdropSnapshotCoordinator.RootSnapshot, rootLocation: IntArray) {
    if (!isCaptureActive()) return
    getLocationInWindow(location)
    val nextOffsetX = (location[0] - rootLocation[0] - snapshot.rect.left).toFloat()
    val nextOffsetY = (location[1] - rootLocation[1] - snapshot.rect.top).toFloat()

    // 陈旧帧守卫：同一版本位图被重新投递且偏移已变化，说明玻璃在两次捕获之间
    // 移动过（translateY 显隐/insets 变化等），继续绘制会把旧位置内容以残影画进
    // 玻璃内部。此时不发射旧位图，并强制下一次遍历立即重捕获。
    if (hasSnapshot && snapshot.version == snapshotVersion &&
      (abs(nextOffsetX - emittedOffsetX) > RootBackdropSnapshotPolicy.snapshotOffsetTolerancePx ||
        abs(nextOffsetY - emittedOffsetY) > RootBackdropSnapshotPolicy.snapshotOffsetTolerancePx)
    ) {
      RootBackdropSnapshotCoordinator.requestImmediateCapture(captureGroup, rootView ?: return)
      clearRootSnapshot()
      return
    }

    // 偏移与版本未变（内容像素未变的去重已在协调器完成）时不重复上报。
    if (hasSnapshot && snapshot.version == snapshotVersion && nextOffsetX == sourceOffsetX && nextOffsetY == sourceOffsetY) return

    sourceOffsetX = nextOffsetX
    sourceOffsetY = nextOffsetY
    emittedOffsetX = nextOffsetX
    emittedOffsetY = nextOffsetY
    snapshotVersion = snapshot.version
    hasSnapshot = true
    emitSnapshot(snapshot.bitmap, nextOffsetX, nextOffsetY)
  }

  override fun clearRootSnapshot() {
    if (!hasSnapshot) return
    emitInvalidSnapshot()
    hasSnapshot = false
    snapshotVersion = -1L
    sourceOffsetX = Float.NaN
    sourceOffsetY = Float.NaN
    emittedOffsetX = Float.NaN
    emittedOffsetY = Float.NaN
  }

  /** 通知 JS 清除上一帧，避免捕获失效后继续显示旧背景。 */
  private fun emitInvalidSnapshot() {
    val payload = Arguments.createMap().apply {
      putString("jpeg", "")
      putDouble("width", 0.0)
      putDouble("height", 0.0)
      putDouble("sourceOffsetX", 0.0)
      putDouble("sourceOffsetY", 0.0)
      putDouble("contentScale", 0.0)
      putDouble("version", -1.0)
    }
    dispatchEvent(payload)
  }

  private fun emitSnapshot(bitmap: Bitmap, offsetX: Float, offsetY: Float) {
    val jpeg = compressJpeg(bitmap) ?: return
    val payload = Arguments.createMap().apply {
      putString("jpeg", jpeg)
      putDouble("width", bitmap.width.toDouble())
      putDouble("height", bitmap.height.toDouble())
      putDouble("sourceOffsetX", offsetX.toDouble())
      putDouble("sourceOffsetY", offsetY.toDouble())
      putDouble("contentScale", RootBackdropSnapshotPolicy.captureScale.toDouble())
      putDouble("version", snapshotVersion.toDouble())
    }
    dispatchEvent(payload)
    if (oneShot) unregister()
  }

  /** JPEG 压缩（0.5x 小区域约 1-3ms，主线程可接受）。超 60KB 放弃，JS 侧降级为静态层。 */
  private fun compressJpeg(bitmap: Bitmap): String? {
    return try {
      val stream = ByteArrayOutputStream()
      if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 70, stream)) return null
      val bytes = stream.toByteArray()
      if (bytes.size > 60 * 1024) return null
      Base64.encodeToString(bytes, Base64.NO_WRAP)
    } catch (_: RuntimeException) {
      null
    }
  }

  /**
   * Fabric 事件派发（RN 0.86 推荐路径）：
   * EventDispatcher.dispatchEvent → Event.dispatchModern → RCTModernEventEmitter.receiveEvent。
   * 事件名遵循 Fabric 约定：JS 侧 onSnapshot ↔ 原生 topSnapshot。
   */
  private fun dispatchEvent(payload: WritableMap) {
    val reactContext = context as? ReactContext ?: return
    try {
      val dispatcher = UIManagerHelper.getEventDispatcher(reactContext) ?: return
      val surfaceId = UIManagerHelper.getSurfaceId(this)
      dispatcher.dispatchEvent(SnapshotEvent(surfaceId, id, payload))
    } catch (_: RuntimeException) {
      // 事件管线不可用时静默降级（JS 侧保持静态层）
    }
  }

  // ---------- 注册 ----------

  private fun isCaptureActive(): Boolean = live && isAttachedToWindow

  private fun updateRegistration() {
    if (isCaptureActive() && width > 0 && height > 0) {
      register()
    } else {
      unregister()
    }
  }

  private fun register() {
    val target = rootView ?: return
    if (registered && source === target) return
    source = target
    registered = true
    RootBackdropSnapshotCoordinator.register(this, target)
  }

  private fun unregister() {
    if (registered) RootBackdropSnapshotCoordinator.unregister(this, source)
    registered = false
    source = null
    clearRootSnapshot()
  }

  private fun dp(value: Double): Float = (value * density).toFloat()
}

/**
 * 背景快照事件（Fabric）。
 * 遵循 RN 的 Event<T> 自引用类型参数模式（Event<T : Event<T>>），
 * 匿名对象（Event<Event<*>>）无法满足泛型约束，必须用具名子类。
 */
private class SnapshotEvent(
  surfaceId: Int,
  viewTag: Int,
  private val payload: WritableMap,
) : Event<SnapshotEvent>(surfaceId, viewTag) {
  override fun getEventName(): String = "topSnapshot"
  override fun getEventData(): WritableMap = payload
  override fun canCoalesce(): Boolean = false
}
