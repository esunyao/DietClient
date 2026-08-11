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

  companion object {
    const val NAME = "AndroidGlassSurface"
  }
}
