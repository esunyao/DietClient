import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../theme/app_colors.dart';
import 'glass_backdrop.dart';

enum GlassMode { off, standard, enhanced }

/// 支持的实时后端或 Windows 背景捕获启用折射；加载失败回退磨砂。
class GlassSurface extends StatefulWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 26,
    this.mode = GlassMode.standard,
    this.reduceTransparency = false,
  });
  final Widget child;
  final double radius;
  final GlassMode mode;
  final bool reduceTransparency;
  static bool get supportsEnhanced =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          (defaultTargetPlatform == TargetPlatform.android &&
              ImageFilter.isShaderFilterSupported));
  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface> {
  Future<bool>? _shader;
  Future<bool> _load() async {
    try {
      await LiquidGlassShaders.ensureLoaded(
        ImageFilter.isShaderFilterSupported,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Widget _lite(bool opaque) => ClipRRect(
    borderRadius: BorderRadius.circular(widget.radius),
    child: BackdropFilter(
      enabled: !opaque,
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: opaque ? 1 : .82),
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(color: AppColors.line),
        ),
        child: widget.child,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final opaque =
        widget.mode == GlassMode.off ||
        widget.reduceTransparency ||
        MediaQuery.highContrastOf(context);
    if (opaque ||
        widget.mode != GlassMode.enhanced ||
        !GlassSurface.supportsEnhanced) {
      return _lite(opaque);
    }
    if (!ImageFilter.isShaderFilterSupported &&
        !GlassCaptureScope.availableOf(context)) {
      return _lite(false);
    }
    _shader ??= _load();
    return FutureBuilder<bool>(
      future: _shader,
      builder: (context, result) {
        if (result.data != true) return _lite(false);
        return LiquidGlassLens(
          style: LiquidGlassStyle(
            shape: LiquidGlassShape.roundedRectangle(
              cornerRadius: widget.radius,
            ),
            blur: 8,
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// 第三方运动镜片保留在包内；应用只传逻辑位置与展示偏好。
class GlassMotionSelection extends StatelessWidget {
  static Future<bool>? _shader;
  static Future<bool> _load() async {
    try {
      await LiquidGlassShaders.ensureLoaded(
        ImageFilter.isShaderFilterSupported,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  const GlassMotionSelection({
    super.key,
    required this.center,
    required this.size,
    required this.active,
    required this.mode,
    required this.reduceTransparency,
  });
  final Offset center;
  final Size size;
  final bool active;
  final GlassMode mode;
  final bool reduceTransparency;
  @override
  Widget build(BuildContext context) {
    final enhanced =
        mode == GlassMode.enhanced &&
        !reduceTransparency &&
        !MediaQuery.highContrastOf(context) &&
        GlassSurface.supportsEnhanced &&
        (ImageFilter.isShaderFilterSupported ||
            GlassCaptureScope.availableOf(context));
    if (enhanced) {
      _shader ??= _load();
      return FutureBuilder<bool>(
        future: _shader,
        builder: (context, result) {
          if (result.data != true) return _fallback();
          return LiquidGlassMotionPill(
            center: center,
            active: active,
            restSize: size,
            activeSize: Size(size.width + 5, size.height + 2),
            cover: ColoredBox(
              color: AppColors.navigationSelected.withValues(alpha: .45),
            ),
          );
        },
      );
    }
    return _fallback();
  }

  Widget _fallback() => Stack(
    children: [
      Positioned(
        left: center.dx - size.width / 2,
        top: center.dy - size.height / 2,
        width: size.width,
        height: size.height,
        child: Transform.scale(
          scaleX: active ? 1.04 : 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.navigationSelected,
              borderRadius: BorderRadius.circular(size.height / 2),
            ),
          ),
        ),
      ),
    ],
  );
}
