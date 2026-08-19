package com.dietclient.glass

/**
 * 根视图背景捕获期间的门闩：协调器光栅化根视图时会置位，
 * 玻璃容器（AndroidGlassSurface / SkiaGlassSurface）在 draw() 中检测到该标志后
 * 跳过自身子树，避免"玻璃自捕获"形成反馈回路。
 */
internal object BackdropCaptureGate {
  private var depth = 0

  fun begin() {
    depth++
  }

  fun end() {
    depth = (depth - 1).coerceAtLeast(0)
  }

  fun isActive(): Boolean = depth > 0
}
