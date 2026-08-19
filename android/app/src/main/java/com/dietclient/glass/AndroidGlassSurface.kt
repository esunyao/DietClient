package com.dietclient.glass

import android.content.Context
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Outline
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.RuntimeShader
import android.graphics.Shader
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.os.Build
import android.view.MotionEvent
import android.view.View
import android.view.ViewOutlineProvider
import com.dietclient.R
import com.facebook.react.views.view.ReactViewGroup
import java.util.IdentityHashMap
import kotlin.math.abs
import kotlin.math.max

/**
 * Android 导航玻璃表面。
 *
 * 液态模式采样 React 根视图的 Bitmap 像素，而不是引用其 RenderNode。这样既能保留
 * Fabric 内容，又不会产生「根视图 -> 玻璃 -> 根视图」的 display list 递归。
 *
 * 快照由 RootBackdropSnapshotCoordinator 按 captureScale 降采样输出；本类把
 * contentScale 与 content 空间 blurRadius 作为 uniform 传给 AGSL shader，采样坐标
 * 在 shader 内统一换算回 content 空间，视觉与 1x 捕获等价。
 */
class AndroidGlassSurface(context: Context) : ReactViewGroup(context), BackdropSnapshotHost {
  private val density = resources.displayMetrics.density
  private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(42, 255, 255, 255) }
  private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    color = Color.argb(120, 148, 163, 184)
    style = Paint.Style.STROKE
    strokeWidth = density
  }
  private val sheenPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(150, 255, 255, 255) }
  private val liquidPaint = Paint(Paint.ANTI_ALIAS_FLAG)
  private val clipRect = RectF()
  private val location = IntArray(2)

  private var variant = "soft"
  private var elevated = false
  private var radiusPx = dp(26.0)
  private var liquidEnabled = false
  private var liquidTouchEffect = false
  private var liquidElasticEffect = false
  private var liquidCaptureGroup = "tab"
  private var refractionHeightPx = dp(20.0)
  private var refractionOffsetPx = dp(70.0)
  private var blurRadiusPx = 0.01f
  private var dispersion = 0.5f
  private var source: View? = null
  private var samplerRegistered = false
  private var shader: RuntimeShader? = null
  private var bitmapShader: BitmapShader? = null
  private val bitmapShaderCache = IdentityHashMap<android.graphics.Bitmap, BitmapShader>()
  private var sampledBitmap: android.graphics.Bitmap? = null
  private var hasRootSnapshot = false
  private var snapshotVersion = -1L
  private var sourceOffsetX = Float.NaN
  private var sourceOffsetY = Float.NaN
  private var generation = 0
  private var touchActive = false
  private var touchX = 0f
  private var touchY = 0f
  private var downX = 0f
  private var downY = 0f

  init {
    setWillNotDraw(false)
    clipToOutline = true
    outlineProvider = object : ViewOutlineProvider() {
      override fun getOutline(view: View, outline: Outline) {
        outline.setRoundRect(0, 0, view.width, view.height, radiusPx)
      }
    }
    updateMaterial()
  }

  fun setVariant(value: String) {
    if (variant == value) return
    variant = value
    updateMaterial()
  }

  fun setElevated(value: Boolean) {
    if (elevated == value) return
    elevated = value
    updateMaterial()
  }

  fun setCornerRadius(value: Double) {
    val nextRadius = LiquidGlassParameterPolicy.cornerRadiusPx(density, value, height)
    if (radiusPx == nextRadius) return
    radiusPx = nextRadius
    applyCornerRadius()
    invalidateOutline()
    updateShaderUniforms()
    invalidate()
  }

  fun setLiquidEnabled(value: Boolean) {
    if (liquidEnabled == value) return
    liquidEnabled = value
    updateMaterial()
  }

  fun setLiquidTouchEffect(value: Boolean) {
    liquidTouchEffect = value
    if (!value) resetTouchEffects()
  }

  fun setLiquidElasticEffect(value: Boolean) {
    liquidElasticEffect = value
    if (!value) animate().scaleX(1f).scaleY(1f).setDuration(120).start()
  }

  fun setLiquidCaptureGroup(value: String?) {
    val nextGroup = if (value == "header") "header" else "tab"
    if (liquidCaptureGroup == nextGroup) return
    liquidCaptureGroup = nextGroup
    clearRootSnapshot()
  }

  fun setLiquidRefractionHeight(value: Double) {
    refractionHeightPx = LiquidGlassParameterPolicy.refractionHeightPx(density, value)
    updateShaderUniforms()
  }

  fun setLiquidRefractionOffset(value: Double) {
    refractionOffsetPx = LiquidGlassParameterPolicy.refractionOffsetPx(density, value)
    updateShaderUniforms()
  }

  fun setLiquidBlurRadius(value: Double) {
    blurRadiusPx = LiquidGlassParameterPolicy.blurRadiusPx(value)
    updateShaderUniforms()
  }

  fun setLiquidDispersion(value: Double) {
    dispersion = LiquidGlassParameterPolicy.dispersion(value)
    updateShaderUniforms()
  }

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    val attachGeneration = ++generation
    post { if (attachGeneration == generation) updateLiquidState() }
  }

  override fun onDetachedFromWindow() {
    generation++
    releaseLiquid()
    resetTouchEffects()
    super.onDetachedFromWindow()
  }

  override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
    super.onSizeChanged(w, h, oldw, oldh)
    if (h > 0) radiusPx = radiusPx.coerceAtMost(h / 2f)
    if (w != oldw || h != oldh) clearRootSnapshot()
    invalidateOutline()
    updateShaderUniforms()
  }

  override fun draw(canvas: Canvas) {
    // 使用软件 Canvas 采样根视图时只跳过液态宿主；静态玻璃卡片仍应进入快照。
    if (BackdropCaptureGate.isActive() && shouldUseLiquid()) return
    super.draw(canvas)
  }

  override fun onDraw(canvas: Canvas) {
    super.onDraw(canvas)
    if (!canDrawLiquid() || !hasRootSnapshot || bitmapShader == null || !canvas.isHardwareAccelerated) return
    clipRect.set(0f, 0f, width.toFloat(), height.toFloat())
    canvas.drawRoundRect(clipRect, radiusPx, radiusPx, liquidPaint)
    canvas.drawRoundRect(clipRect, radiusPx, radiusPx, fillPaint)
  }

  override fun dispatchDraw(canvas: Canvas) {
    super.dispatchDraw(canvas)
    if (canDrawLiquid()) {
      val halfStroke = borderPaint.strokeWidth / 2f
      canvas.drawRoundRect(halfStroke, halfStroke, width - halfStroke, height - halfStroke, radiusPx, radiusPx, borderPaint)
      canvas.drawRoundRect(radiusPx, 0f, (width - radiusPx).coerceAtLeast(radiusPx), density * 2f, density, density, sheenPaint)
      if (liquidTouchEffect && touchActive) drawTouchGlow(canvas)
    }
  }

  override fun dispatchTouchEvent(event: MotionEvent): Boolean {
    if (canDrawLiquid() && (liquidTouchEffect || liquidElasticEffect)) observeTouch(event)
    return super.dispatchTouchEvent(event)
  }

  override fun snapshotRequest(root: View, rootLocation: IntArray): RootBackdropSnapshotCoordinator.SnapshotRequest? {
    if (!canDrawLiquid() || source !== root || width <= 0 || height <= 0) return null
    getLocationInWindow(location)
    val left = location[0] - rootLocation[0]
    val top = location[1] - rootLocation[1]
    val padding = RootBackdropSnapshotPolicy.capturePaddingPx(refractionHeightPx, refractionOffsetPx, blurRadiusPx, density)
    return RootBackdropSnapshotCoordinator.SnapshotRequest(
      host = this,
      group = liquidCaptureGroup,
      captureRect = Rect(left - padding, top - padding, left + width + padding, top + height + padding),
    )
  }

  override fun acceptRootSnapshot(snapshot: RootBackdropSnapshotCoordinator.RootSnapshot, rootLocation: IntArray) {
    if (!canDrawLiquid()) return
    getLocationInWindow(location)
    val nextOffsetX = (location[0] - rootLocation[0] - snapshot.rect.left).toFloat()
    val nextOffsetY = (location[1] - rootLocation[1] - snapshot.rect.top).toFloat()
    try {
      val versionChanged = snapshot.version != snapshotVersion
      val bitmapChanged = snapshot.bitmap !== sampledBitmap || bitmapShader == null
      val offsetChanged = nextOffsetX != sourceOffsetX || nextOffsetY != sourceOffsetY
      val shouldInvalidate = RootBackdropSnapshotPolicy.needsSnapshotInvalidation(
        hasSnapshot = hasRootSnapshot,
        versionChanged = versionChanged,
        bitmapChanged = bitmapChanged,
        offsetChanged = offsetChanged,
      )

      if (bitmapChanged) {
        if (!bitmapShaderCache.containsKey(snapshot.bitmap) && bitmapShaderCache.size >= RootBackdropSnapshotPolicy.bufferCount) {
          bitmapShaderCache.clear()
        }
        bitmapShader = bitmapShaderCache.getOrPut(snapshot.bitmap) {
          BitmapShader(snapshot.bitmap, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        }
        shader?.setInputShader("content", bitmapShader!!)
        sampledBitmap = snapshot.bitmap
      }
      if (versionChanged) snapshotVersion = snapshot.version
      if (offsetChanged) {
        sourceOffsetX = nextOffsetX
        sourceOffsetY = nextOffsetY
        updateShaderUniforms()
      }
      hasRootSnapshot = true
      if (shouldInvalidate) {
        RootBackdropSnapshotCoordinator.recordInvalidation(liquidCaptureGroup)
        invalidate()
      }
    } catch (_: RuntimeException) {
      clearRootSnapshot()
    }
  }

  override fun clearRootSnapshot() {
    if (!RootBackdropSnapshotPolicy.needsSnapshotClear(hasRootSnapshot, bitmapShader != null)) return
    hasRootSnapshot = false
    bitmapShader = null
    sampledBitmap = null
    snapshotVersion = -1L
    sourceOffsetX = Float.NaN
    sourceOffsetY = Float.NaN
    invalidate()
  }

  private fun observeTouch(event: MotionEvent) {
    when (event.actionMasked) {
      MotionEvent.ACTION_DOWN -> {
        downX = event.x
        downY = event.y
        touchX = event.x
        touchY = event.y
        touchActive = true
        invalidate()
      }
      MotionEvent.ACTION_MOVE -> {
        touchX = event.x
        touchY = event.y
        if (liquidElasticEffect) {
          val dx = (event.x - downX) / max(width, 1)
          val dy = (event.y - downY) / max(height, 1)
          scaleX = (1f + abs(dx) * 0.08f - abs(dy) * 0.035f).coerceIn(0.96f, 1.05f)
          scaleY = (1f + abs(dy) * 0.08f - abs(dx) * 0.035f).coerceIn(0.96f, 1.05f)
        }
        invalidate()
      }
      MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> resetTouchEffects()
    }
  }

  private fun resetTouchEffects() {
    touchActive = false
    animate().scaleX(1f).scaleY(1f).setDuration(160).start()
    invalidate()
  }

  private fun drawTouchGlow(canvas: Canvas) {
    val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(35, 255, 255, 255) }
    canvas.drawCircle(touchX, touchY, max(width, height) * 0.55f, glow)
  }

  private fun updateMaterial() {
    background = context.getDrawable(
      if (variant == "navigation") R.drawable.bg_glass_navigation else R.drawable.bg_glass_soft,
    )?.mutate()
    applyCornerRadius()
    elevation = if (elevated) dp(1.0) else 0f
    translationZ = elevation
    if (shouldUseLiquid()) {
      setLayerType(LAYER_TYPE_HARDWARE, null)
      updateLiquidState()
    } else {
      setLayerType(LAYER_TYPE_NONE, null)
      releaseLiquid()
    }
    invalidate()
  }

  private fun applyCornerRadius() {
    val base = (background as? LayerDrawable)?.getDrawable(0) as? GradientDrawable
    base?.cornerRadius = radiusPx
  }

  private fun updateLiquidState() {
    if (!shouldUseLiquid() || !isAttachedToWindow || width <= 0 || height <= 0) {
      if (!shouldUseLiquid()) releaseLiquid()
      return
    }
    val target = rootView
    if (!target.isAttachedToWindow) return
    if (!ensureShader()) return
    if (source !== target) {
      if (samplerRegistered) RootBackdropSnapshotCoordinator.unregister(this, source)
      source = target
      samplerRegistered = true
      RootBackdropSnapshotCoordinator.register(this, target)
    } else if (!samplerRegistered) {
      samplerRegistered = true
      RootBackdropSnapshotCoordinator.register(this, target)
    }
  }

  private fun ensureShader(): Boolean {
    if (shader != null) return true
    return try {
      shader = RuntimeShader(readShader())
      liquidPaint.shader = shader
      updateShaderUniforms()
      true
    } catch (_: RuntimeException) {
      liquidEnabled = false
      updateMaterial()
      false
    }
  }

  private fun updateShaderUniforms() {
    val runtimeShader = shader ?: return
    if (width <= 0 || height <= 0) return
    runtimeShader.setFloatUniform("size", width.toFloat(), height.toFloat())
    runtimeShader.setFloatUniform("cornerRadii", radiusPx, radiusPx)
    runtimeShader.setFloatUniform("refractionHeight", refractionHeightPx)
    runtimeShader.setFloatUniform("refractionAmount", -refractionOffsetPx)
    runtimeShader.setFloatUniform("chromaticAberration", dispersion)
    // 快照已按 captureScale 降采样：blurRadius 换算为 content 空间半径，采样坐标同步缩放。
    runtimeShader.setFloatUniform("blurRadius", blurRadiusPx * RootBackdropSnapshotPolicy.captureScale)
    runtimeShader.setFloatUniform("contentScale", RootBackdropSnapshotPolicy.captureScale)
    runtimeShader.setFloatUniform("sourceOffset", if (sourceOffsetX.isNaN()) 0f else sourceOffsetX, if (sourceOffsetY.isNaN()) 0f else sourceOffsetY)
  }

  private fun releaseLiquid() {
    if (samplerRegistered) RootBackdropSnapshotCoordinator.unregister(this, source)
    samplerRegistered = false
    source = null
    bitmapShader = null
    bitmapShaderCache.clear()
    sampledBitmap = null
    hasRootSnapshot = false
    liquidPaint.shader = null
    shader = null
    snapshotVersion = -1L
    sourceOffsetX = Float.NaN
    sourceOffsetY = Float.NaN
  }

  private fun shouldUseLiquid(): Boolean =
    LiquidGlassParameterPolicy.supportsLiquidGlass(Build.VERSION.SDK_INT) && liquidEnabled && variant == "navigation"

  private fun canDrawLiquid(): Boolean =
    shouldUseLiquid() && isAttachedToWindow && source?.isAttachedToWindow == true && shader != null

  private fun readShader(): String = resources.openRawResource(R.raw.liquid_glass_effect).bufferedReader().use { it.readText() }

  private fun dp(value: Double): Float = (value * density).toFloat()

}
