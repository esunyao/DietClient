import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// @brief 判断是否启用 Web UI 预览模式。
/// @details 编译期开关只允许 Web 预览，不赋予任何认证身份。
/// @param web 当前是否为 Web 运行环境。
/// @param enabled 编译期预览开关值。
/// @return 同时满足 Web 环境与预览开关开启时返回 true，否则返回 false。
bool isUiPreviewEnabled({required bool web, required bool enabled}) =>
    web && enabled;

final uiPreviewProvider = Provider<bool>(
  (ref) => isUiPreviewEnabled(
    web: kIsWeb,
    enabled: const bool.fromEnvironment('WEB_UI_PREVIEW'),
  ),
);

/// @brief 原生真实膳食功能启用开关 Provider。
/// @details 本轮真实膳食功能仅装配 Android/Windows 平台；Web 保留原有页面。
final nativeNutritionEnabledProvider = Provider<bool>(
  (ref) =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.windows) &&
      !ref.watch(uiPreviewProvider),
);
