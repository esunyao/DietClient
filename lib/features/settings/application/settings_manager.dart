import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/ui_preview_config.dart';
import '../../../core/presentation/display_state.dart';
import '../../../core/presentation/ui_preferences.dart';
import '../../../demo/demo_store.dart';

/// 外观与体验设置管理器 Provider，统一协调外观偏好保存、显示模式切换及重置逻辑。
final settingsManagerProvider = Provider<SettingsManager>(SettingsManager.new);

/// 应用设置业务管理器，隔离设置界面与底层偏好、演示状态及临时显示状态的更新细节。
class SettingsManager {
  SettingsManager(this._ref);

  final Ref _ref;

  /// 更新饮食历史视图布局偏好。
  Future<void> setMealHistoryLayout(MealHistoryLayout layout) =>
      _ref.read(uiPreferencesProvider.notifier).setMealHistoryLayout(layout);

  /// 更新全局玻璃质感档位。
  Future<void> setGlassMode(GlassMode mode) =>
      _ref.read(uiPreferencesProvider.notifier).setGlassMode(mode);

  /// 更新减少透明度偏好。
  Future<void> setReduceTransparency(bool value) =>
      _ref.read(uiPreferencesProvider.notifier).setReduceTransparency(value);

  /// 更新减少动态效果偏好。
  Future<void> setReduceMotion(bool value) =>
      _ref.read(uiPreferencesProvider.notifier).setReduceMotion(value);

  /// 重新加载本机外观偏好设置。
  Future<void> reloadPreferences() =>
      _ref.read(uiPreferencesProvider.notifier).reload();

  /// 切换个人或机构体验显示模式；预览环境下同步重置演示样例。
  void selectExperienceMode(ExperienceMode mode) {
    if (_ref.read(uiPreviewProvider)) {
      _ref.read(demoProvider.notifier).selectMode(mode);
    } else {
      _ref.read(displayStateProvider.notifier).selectMode(mode);
    }
  }

  /// 立即开启或关闭个人信息临时隐私遮罩。
  void setPrivacyHidden(bool hidden) {
    if (_ref.read(uiPreviewProvider)) {
      _ref.read(demoProvider.notifier).setPrivacyHidden(hidden);
    } else {
      _ref.read(displayStateProvider.notifier).setPrivacyHidden(hidden);
    }
  }

  /// 重置默认外观；预览环境下同时恢复内存演示数据，并返回可展示的提示文案。
  Future<String> resetDefaults() async {
    final preview = _ref.read(uiPreviewProvider);
    if (preview) {
      _ref.read(demoProvider.notifier).reset();
    }
    await _ref.read(uiPreferencesProvider.notifier).reset();
    if (!_ref.mounted) {
      return preview ? '内存演示已恢复初始样例' : '已恢复默认外观';
    }
    final result = _ref.read(uiPreferencesProvider);
    return result.error ?? (preview ? '内存演示已恢复初始样例' : '已恢复默认外观');
  }
}
