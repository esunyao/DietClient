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

// ConsumerStatefulWidget 是 StatefulWidget 与 Riverpod 状态读取/监听能力 的结合体
class DietApp extends ConsumerStatefulWidget {
  const DietApp({super.key});
  @override
  ConsumerState<DietApp> createState() => _DietAppState();
}

class _DietAppState extends ConsumerState<DietApp> with WidgetsBindingObserver {
  @override
  // 启动恢复与生命周期监听注册
  void initState() {
    super.initState();
    // 监听应用的切前后台等系统级生命周期事件。
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
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
    ref.watch(currentDateProvider);
    ref.listen(sessionProvider, (previous, next) {
      if (previous != null && next == null) {
        ref.read(displayStateProvider.notifier).setPrivacyHidden(false);
      }
    });
    final signedIn = hasActiveSession(ref.watch(sessionProvider));
    final uiPreview = ref.watch(uiPreviewProvider);
    final prefs = ref.watch(uiPreferencesProvider);
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
