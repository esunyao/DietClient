import 'dart:async';

import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/ui_preview_config.dart';
import '../core/presentation/ui_preferences.dart';
import '../core/presentation/current_date.dart';
import '../core/presentation/display_state.dart';
import '../core/nutrition/application/nutrition_providers.dart';
import '../core/session/session_controller.dart';
import '../demo/demo_store.dart';
import 'router.dart';

/// @brief 应用根组件。
/// @details 继承自 ConsumerStatefulWidget，结合 StatefulWidget 生命周期与 Riverpod 状态读取和监听能力。
class DietApp extends ConsumerStatefulWidget {
  const DietApp({super.key});
  @override
  ConsumerState<DietApp> createState() => _DietAppState();
}

class _DietAppState extends ConsumerState<DietApp> with WidgetsBindingObserver {
  /// @brief 初始化应用状态，注册系统生命周期监听并安排启动会话恢复。
  @override
  void initState() {
    super.initState();
    // 监听应用的切前后台等系统级生命周期事件。
    WidgetsBinding.instance.addObserver(this);
    // 延后到微任务启动恢复；预览不恢复会话，仅 booting 状态触发。
    Future.microtask(() {
      // mounted 当前组件是否存活
      if (mounted &&
          !ref.read(uiPreviewProvider) &&
          ref.read(sessionStatusProvider) == SessionStatus.booting) {
        unawaited(ref.read(sessionProvider.notifier).restore());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// @brief 响应应用前后台生命周期变化。
  /// @details 回到前台时复核本地日期和会话有效性；仅原生营养启用且会话就绪时刷新营养查询。
  /// @param state 当前应用生命周期状态。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(currentDateProvider.notifier).refresh();
      ref.read(sessionProvider.notifier).checkExpiry();
      if (ref.read(nativeNutritionEnabledProvider) &&
          ref.read(sessionStatusProvider) == SessionStatus.ready &&
          hasActiveSession(ref.read(sessionProvider))) {
        refreshNutrition(ref);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 保持本地日期订阅；会话清空时重置真实隐私遮罩，避免沿用上个会话的显示状态。
    ref.watch(currentDateProvider);
    ref.listen(sessionProvider, (previous, next) {
      if (previous != null && next == null) {
        ref.read(displayStateProvider.notifier).setPrivacyHidden(false);
      }
    });
    final signedIn = hasActiveSession(ref.watch(sessionProvider));
    final uiPreview = ref.watch(uiPreviewProvider);
    final prefs = ref.watch(uiPreferencesProvider);
    // 机构遮罩仅控制界面可见性：预览读演示状态，正常路径读真实展示状态。
    final hidden =
        (signedIn || uiPreview) &&
        (uiPreview
            ? ref.watch(
                demoProvider.select((s) => s.isInstitution && s.privacyHidden),
              )
            : ref.watch(
                displayStateProvider.select(
                  (s) => s.isInstitution && s.privacyHidden,
                ),
              ));
    return MaterialApp.router(
      title: uiPreview ? '膳食健康 · UI预览' : '膳食健康',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) {
        // 合并系统和应用的减少动态设置；遮罩期间保留页面树但停用其动画。
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            disableAnimations: media.disableAnimations || prefs.reduceMotion,
          ),
          child: Stack(
            children: [
              Offstage(
                offstage: hidden,
                child: TickerMode(
                  enabled: !hidden,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
              if (hidden)
                Positioned.fill(
                  child: Material(
                    color: AppColors.canvas,
                    child: SafeArea(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 380),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.visibility_off_outlined,
                                  size: 48,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  '个人信息已暂时隐藏',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  uiPreview
                                      ? '共享平板演示遮罩。恢复仅演示界面，不代表真实身份核验。'
                                      : '此操作仅隐藏界面，当前账户仍保持登录。',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.muted),
                                ),
                                const SizedBox(height: 24),
                                AppButton(
                                  label: uiPreview ? '恢复演示预览' : '恢复显示',
                                  onPressed: () {
                                    if (uiPreview) {
                                      ref
                                          .read(demoProvider.notifier)
                                          .setPrivacyHidden(false);
                                    } else {
                                      ref
                                          .read(displayStateProvider.notifier)
                                          .setPrivacyHidden(false);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
