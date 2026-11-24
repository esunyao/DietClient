import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'glass_surface.dart';

/// 分离背景页面与玻璃覆盖层的容器；Windows 仅捕获背景子树，避免切档重挂载页面状态。
class GlassBackdrop extends StatefulWidget {
  const GlassBackdrop({
    super.key,
    required this.background,
    required this.overlay,
    this.mode = GlassMode.standard,
    this.reduceTransparency = false,
  });

  final Widget background;
  final Widget overlay;
  final GlassMode mode;
  final bool reduceTransparency;

  @override
  State<GlassBackdrop> createState() => _GlassBackdropState();
}

class _GlassBackdropState extends State<GlassBackdrop> {
  bool _loading = false;
  bool _ready = false;

  void _load() {
    if (_loading) return;
    _loading = true;
    LiquidGlassShaders.ensureLoaded(ImageFilter.isShaderFilterSupported)
        .then((_) {
          if (mounted) setState(() => _ready = true);
        })
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final capture =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        !ImageFilter.isShaderFilterSupported;
    final enhanced =
        widget.mode == GlassMode.enhanced &&
        !widget.reduceTransparency &&
        !MediaQuery.highContrastOf(context);
    if (capture && enhanced) _load();
    final foreground = GlassCaptureScope(
      available: capture && enhanced && _ready,
      child: widget.overlay,
    );
    // 保持 View 位置和类型稳定，切档不重挂载有状态的背景页面。
    if (capture) {
      return LiquidGlassView(
        backgroundWidget: widget.background,
        useImpellerBackdrop: false,
        realTimeCapture: enhanced && _ready,
        pixelRatio: 1,
        useSync: true,
        refreshRate: LiquidGlassRefreshRate.high,
        child: foreground,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [widget.background, foreground],
    );
  }
}

/// 向包内玻璃组件传递当前背景捕获可用性，不从公共入口导出。
class GlassCaptureScope extends InheritedWidget {
  const GlassCaptureScope({
    super.key,
    required this.available,
    required super.child,
  });
  final bool available;

  /// 读取当前树上最近 [GlassCaptureScope] 的背景捕获可用状态。
  static bool availableOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<GlassCaptureScope>()
          ?.available ??
      false;

  @override
  bool updateShouldNotify(GlassCaptureScope oldWidget) =>
      oldWidget.available != available;
}
