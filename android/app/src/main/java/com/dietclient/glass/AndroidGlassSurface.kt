package com.dietclient.glass

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Outline
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.view.View
import android.view.ViewOutlineProvider
import com.facebook.react.views.view.ReactViewGroup
import kotlin.math.max

/**
 * Android 的稳定类玻璃表面。
 *
 * 此 View 只绘制本身的材质和描边，绝不对自身或子视图调用 RenderEffect：
 * React Text/图标仍由普通 View 层绘制，因此不会出现模糊文字或上一帧残影。
 */
class AndroidGlassSurface(context: Context) : ReactViewGroup(context) {
  private val density = resources.displayMetrics.density
  private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
  private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
  private val sheenPaint = Paint(Paint.ANTI_ALIAS_FLAG)
  private val rect = RectF()

  private var variant = "soft"
  private var elevated = false
  private var radiusPx = dp(26.0)

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
    invalidate()
  }

  fun setElevated(value: Boolean) {
    if (elevated == value) return
    elevated = value
    updateMaterial()
  }

  fun setCornerRadius(value: Double) {
    val nextRadius = dp(max(0.0, value))
    if (radiusPx == nextRadius) return
    radiusPx = nextRadius
    invalidateOutline()
    invalidate()
  }

  private fun updateMaterial() {
    val navigation = variant == "navigation"
    fillPaint.color = if (navigation) Color.argb(224, 255, 255, 255) else Color.argb(191, 255, 255, 255)
    borderPaint.color = if (navigation) Color.argb(122, 148, 163, 184) else Color.argb(224, 255, 255, 255)
    borderPaint.strokeWidth = max(1f, density)
    elevation = if (elevated) dp(1.0) else 0f
    translationZ = elevation
  }

  override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
    super.onSizeChanged(w, h, oldw, oldh)
    invalidateOutline()
  }

  override fun onDraw(canvas: Canvas) {
    rect.set(0f, 0f, width.toFloat(), height.toFloat())
    canvas.drawRoundRect(rect, radiusPx, radiusPx, fillPaint)

    val sheenHeight = minOf(dp(3.0).toFloat(), height.toFloat())
    sheenPaint.shader = LinearGradient(
      0f,
      0f,
      0f,
      sheenHeight,
      Color.argb(190, 255, 255, 255),
      Color.argb(0, 255, 255, 255),
      Shader.TileMode.CLAMP,
    )
    canvas.drawRoundRect(rect, radiusPx, radiusPx, sheenPaint)
    sheenPaint.shader = null

    val halfStroke = borderPaint.strokeWidth / 2f
    rect.inset(halfStroke, halfStroke)
    canvas.drawRoundRect(rect, max(0f, radiusPx - halfStroke), max(0f, radiusPx - halfStroke), borderPaint)
  }

  private fun dp(value: Double): Float = (value * density).toFloat()
}
