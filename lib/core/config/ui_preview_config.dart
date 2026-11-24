import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 判断是否启用 Web UI 预览模式；仅在 Web 且显式开启编译期开关时生效。
bool isUiPreviewEnabled({required bool web, required bool enabled}) =>
    web && enabled;

/// Web UI 预览模式开关 Provider。
final uiPreviewProvider = Provider<bool>(
  (ref) => isUiPreviewEnabled(
    web: kIsWeb,
    enabled: const bool.fromEnvironment('WEB_UI_PREVIEW'),
  ),
);

/// 原生真实膳食功能启用开关 Provider（仅 Android 与 Windows 非预览环境开启）。
final nativeNutritionEnabledProvider = Provider<bool>(
  (ref) =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.windows) &&
      !ref.watch(uiPreviewProvider),
);
