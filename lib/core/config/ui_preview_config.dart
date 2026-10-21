import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 编译期开关只允许 Web 预览，不赋予任何认证身份。
bool isUiPreviewEnabled({required bool web, required bool enabled}) =>
    web && enabled;

final uiPreviewProvider = Provider<bool>(
  (ref) => isUiPreviewEnabled(
    web: kIsWeb,
    enabled: const bool.fromEnvironment('WEB_UI_PREVIEW'),
  ),
);

/// 本轮真实膳食功能只装配 Android/Windows；Web 保留原有页面。
final nativeNutritionEnabledProvider = Provider<bool>(
  (ref) =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.windows) &&
      !ref.watch(uiPreviewProvider),
);
