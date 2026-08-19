package com.dietclient.glass

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.viewmanagers.SkiaGlassSurfaceManagerDelegate
import com.facebook.react.viewmanagers.SkiaGlassSurfaceManagerInterface

@ReactModule(name = SkiaGlassSurfaceManager.NAME)
class SkiaGlassSurfaceManager : ViewGroupManager<SkiaGlassSurface>(),
  SkiaGlassSurfaceManagerInterface<SkiaGlassSurface> {
  private val delegate = SkiaGlassSurfaceManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<SkiaGlassSurface> = delegate

  override fun getName(): String = NAME

  override fun createViewInstance(context: ThemedReactContext): SkiaGlassSurface = SkiaGlassSurface(context)

  override fun setCornerRadius(view: SkiaGlassSurface, cornerRadius: Double) {
    view.setCornerRadius(cornerRadius)
  }

  override fun setElevated(view: SkiaGlassSurface, elevated: Boolean) {
    view.setElevated(elevated)
  }

  override fun setLive(view: SkiaGlassSurface, live: Boolean) {
    view.setLive(live)
  }

  override fun setOneShot(view: SkiaGlassSurface, oneShot: Boolean) {
    view.setOneShot(oneShot)
  }

  override fun setLiquidEnabled(view: SkiaGlassSurface, liquidEnabled: Boolean) {
    view.setLiquidEnabled(liquidEnabled)
  }

  override fun setLiquidCaptureGroup(view: SkiaGlassSurface, liquidCaptureGroup: String?) {
    view.setLiquidCaptureGroup(liquidCaptureGroup)
  }

  override fun setLiquidRefractionHeight(view: SkiaGlassSurface, liquidRefractionHeight: Double) {
    view.setLiquidRefractionHeight(liquidRefractionHeight)
  }

  override fun setLiquidRefractionOffset(view: SkiaGlassSurface, liquidRefractionOffset: Double) {
    view.setLiquidRefractionOffset(liquidRefractionOffset)
  }

  override fun setLiquidBlurRadius(view: SkiaGlassSurface, liquidBlurRadius: Double) {
    view.setLiquidBlurRadius(liquidBlurRadius)
  }

  override fun setLiquidDispersion(view: SkiaGlassSurface, liquidDispersion: Double) {
    // 色散在 JS 侧 SkSL 内生效；此属性仅保持接口一致。
  }

  companion object {
    const val NAME = "SkiaGlassSurface"
  }
}
