import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/ui_preview_config.dart';
import '../core/nutrition/application/nutrition_manager.dart';
import '../core/presentation/current_date.dart';
import '../core/presentation/display_state.dart';
import '../core/session/session_controller.dart';
import '../demo/demo_store.dart';
import '../features/auth/application/login_controller.dart';

/// 应用级生命周期与会话编排管理器 Provider。
final appLifecycleManagerProvider = Provider<AppLifecycleManager>(
  AppLifecycleManager.new,
);

/// 应用级管理器，协调启动恢复、前后台刷新、退出登录与预览/真实体验模式访问。
class AppLifecycleManager {
  AppLifecycleManager(this._ref);

  final Ref _ref;

  /// 非预览模式下若处于启动阶段，触发本机记住登录恢复。
  void restoreSessionIfNeeded() {
    if (_ref.read(uiPreviewProvider)) return;
    _ref.read(sessionProvider.notifier).restoreIfBooting();
  }

  /// 应用回到前台时刷新本地日期、检查会话有效性并在就绪时刷新真实营养查询。
  void handleAppResumed() {
    _ref.read(currentDateProvider.notifier).refresh();
    _ref.read(sessionProvider.notifier).checkExpiry();
    if (_ref.read(nativeNutritionEnabledProvider) &&
        _ref.read(sessionStatusProvider) == SessionStatus.ready &&
        hasActiveSession(_ref.read(sessionProvider))) {
      _ref.read(nutritionManagerProvider).refreshAll();
    }
  }

  /// 会话清空后重置真实界面的临时隐私遮罩。
  void handleSessionCleared() {
    _ref.read(displayStateProvider.notifier).setPrivacyHidden(false);
  }

  /// 退出当前应用会话并使认证网关失效，不注销单点登录。
  void signOut() {
    _ref.invalidate(authGatewayProvider);
    _ref.read(sessionProvider.notifier).clear();
  }

  /// 按当前是否处于 Web UI 预览模式切换隐私遮罩可见性。
  void setPrivacyHidden(bool hidden) {
    if (_ref.read(uiPreviewProvider)) {
      _ref.read(demoProvider.notifier).setPrivacyHidden(hidden);
    } else {
      _ref.read(displayStateProvider.notifier).setPrivacyHidden(hidden);
    }
  }

  /// 按当前是否处于 Web UI 预览模式切换体验模式。
  void selectExperienceMode(ExperienceMode mode) {
    if (_ref.read(uiPreviewProvider)) {
      _ref.read(demoProvider.notifier).selectMode(mode);
    } else {
      _ref.read(displayStateProvider.notifier).selectMode(mode);
    }
  }
}
