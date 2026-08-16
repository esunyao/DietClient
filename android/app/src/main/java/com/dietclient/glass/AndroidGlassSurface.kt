package com.dietclient.glass

import android.content.Context
import android.graphics.Outline
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.view.View
import android.view.ViewOutlineProvider
import com.dietclient.R
import com.facebook.react.views.view.ReactViewGroup
import kotlin.math.max

/**
 * Android 的稳定类玻璃表面。
 *
 * 材质（半透明白填充、顶部高光、描边）全部定义在 res/drawable/bg_glass_soft.xml /
 * bg_glass_navigation.xml，Layout Editor 可直接预览与修改；
 * 本类只负责按 variant 换背景、按 cornerRadius 动态调整圆角并裁剪子视图，
 * 绝不对自身或子视图调用 RenderEffect：React Text/图标仍由普通 View 层绘制，
 * 因此不会出现模糊文字或上一帧残影。
 */
class AndroidGlassSurface(context: Context) : ReactViewGroup(context) {
  private val density = resources.displayMetrics.density
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
    applyCornerRadius()
    invalidateOutline()
  }

  private fun updateMaterial() {
    val navigation = variant == "navigation"
    // mutate() 确保每个实例持有独立副本，避免共享资源常量导致圆角互相串改
    background = context.getDrawable(
      if (navigation) R.drawable.bg_glass_navigation else R.drawable.bg_glass_soft,
    )?.mutate()
    applyCornerRadius()
    elevation = if (elevated) dp(1.0) else 0f
    translationZ = elevation
    invalidate()
  }

  /** XML 圆角只是基准值，按 JS 传入的 cornerRadius 覆盖为实际值。 */
  private fun applyCornerRadius() {
    val base = (background as? LayerDrawable)?.getDrawable(0) as? GradientDrawable
    base?.cornerRadius = radiusPx
  }

  override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
    super.onSizeChanged(w, h, oldw, oldh)
    invalidateOutline()
  }

  private fun dp(value: Double): Float = (value * density).toFloat()
}
