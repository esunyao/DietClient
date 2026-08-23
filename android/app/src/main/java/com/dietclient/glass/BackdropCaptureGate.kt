package com.dietclient.glass

import java.util.IdentityHashMap

/** 捕获根视图时可临时排除自身渲染的宿主。 */
internal interface BackdropCaptureExcludable {
  fun setExcludedFromBackdropCapture(excluded: Boolean)
}

/**
 * 根视图背景捕获期间的门闩：协调器光栅化根视图时会置位，
 * 玻璃容器（AndroidGlassSurface / SkiaGlassSurface）在 draw() 中检测到该标志后
 * 跳过自身子树，避免"玻璃自捕获"形成反馈回路。Fabric 可能复用子视图的硬件显示列表，
 * 因此同时临时将已注册宿主设为 INVISIBLE，确保根视图遍历不会复合旧图层。
 */
internal object BackdropCaptureGate {
  private var depth = 0
  private val exclusionDepths = IdentityHashMap<BackdropCaptureExcludable, Int>()

  fun begin() {
    depth++
  }

  fun end() {
    depth = (depth - 1).coerceAtLeast(0)
  }

  fun isActive(): Boolean = depth > 0

  /**
   * 在同步根视图截图期间排除宿主；支持嵌套调用并在异常时按相反顺序恢复。
   * 使用 identity 计数，避免同一 Fabric 宿主在嵌套捕获中被过早恢复。
   */
  fun <T> withExcludedHosts(hosts: Collection<BackdropCaptureExcludable>, block: () -> T): T {
    val acquired = ArrayList<BackdropCaptureExcludable>(hosts.size)
    var entered = false
    try {
      hosts.forEach { host ->
        val previousDepth = exclusionDepths[host] ?: 0
        if (previousDepth == 0) host.setExcludedFromBackdropCapture(true)
        exclusionDepths[host] = previousDepth + 1
        acquired += host
      }
      begin()
      entered = true
      return block()
    } finally {
      if (entered) end()
      acquired.asReversed().forEach { host ->
        val previousDepth = exclusionDepths[host] ?: return@forEach
        if (previousDepth <= 1) {
          exclusionDepths.remove(host)
          host.setExcludedFromBackdropCapture(false)
        } else {
          exclusionDepths[host] = previousDepth - 1
        }
      }
    }
  }
}
