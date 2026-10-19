import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/presentation/ui_preferences.dart';
import '../demo/demo_store.dart';
import 'router.dart';

class DietApp extends ConsumerWidget {
  const DietApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(uiPreferencesProvider);
    final hidden = ref.watch(
      demoProvider.select((s) => s.isInstitution && s.privacyHidden),
    );
    return MaterialApp.router(
      title: '膳食健康 · UI演示',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
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
                                const Text(
                                  '共享平板演示遮罩。恢复仅演示界面，不代表真实身份核验。',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.muted),
                                ),
                                const SizedBox(height: 24),
                                AppButton(
                                  label: '恢复演示预览',
                                  onPressed: () => ref
                                      .read(demoProvider.notifier)
                                      .setPrivacyHidden(false),
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
