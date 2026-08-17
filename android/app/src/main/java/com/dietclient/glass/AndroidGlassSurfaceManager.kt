package com.dietclient.glass

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.viewmanagers.AndroidGlassSurfaceManagerDelegate
import com.facebook.react.viewmanagers.AndroidGlassSurfaceManagerInterface

@ReactModule(name = AndroidGlassSurfaceManager.NAME)
class AndroidGlassSurfaceManager : ViewGroupManager<AndroidGlassSurface>(),
  AndroidGlassSurfaceManagerInterface<AndroidGlassSurface> {
  private val delegate = AndroidGlassSurfaceManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<AndroidGlassSurface> = delegate

  override fun getName(): String = NAME

  override fun createViewInstance(context: ThemedReactContext): AndroidGlassSurface = AndroidGlassSurface(context)

  override fun setVariant(view: AndroidGlassSurface, variant: String?) {
    view.setVariant(variant ?: "soft")
  }

  override fun setElevated(view: AndroidGlassSurface, elevated: Boolean) {
    view.setElevated(elevated)
  }

  override fun setCornerRadius(view: AndroidGlassSurface, cornerRadius: Double) {
    view.setCornerRadius(cornerRadius)
  }

  override fun setLiquidEnabled(view: AndroidGlassSurface, liquidEnabled: Boolean) {
    view.setLiquidEnabled(liquidEnabled)
  }

  override fun setLiquidTouchEffect(view: AndroidGlassSurface, liquidTouchEffect: Boolean) {
    view.setLiquidTouchEffect(liquidTouchEffect)
  }

  override fun setLiquidElasticEffect(view: AndroidGlassSurface, liquidElasticEffect: Boolean) {
    view.setLiquidElasticEffect(liquidElasticEffect)
  }

  override fun setLiquidCaptureGroup(view: AndroidGlassSurface, liquidCaptureGroup: String?) {
    view.setLiquidCaptureGroup(liquidCaptureGroup)
  }

  override fun setLiquidRefractionHeight(view: AndroidGlassSurface, liquidRefractionHeight: Double) {
    view.setLiquidRefractionHeight(liquidRefractionHeight)
  }

  override fun setLiquidRefractionOffset(view: AndroidGlassSurface, liquidRefractionOffset: Double) {
    view.setLiquidRefractionOffset(liquidRefractionOffset)
  }

  override fun setLiquidBlurRadius(view: AndroidGlassSurface, liquidBlurRadius: Double) {
    view.setLiquidBlurRadius(liquidBlurRadius)
  }

  override fun setLiquidDispersion(view: AndroidGlassSurface, liquidDispersion: Double) {
    view.setLiquidDispersion(liquidDispersion)
  }

  companion object {
    const val NAME = "AndroidGlassSurface"
  }
}
