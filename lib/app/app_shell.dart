import 'dart:math' as math;

import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'navigation_collapse_controller.dart';
import '../core/presentation/app_routes.dart';
import '../core/presentation/ui_preferences.dart';
import '../core/session/session_controller.dart';
import '../demo/demo_store.dart';
import '../features/auth/application/login_controller.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _collapse = NavigationCollapseController();
  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) _collapse.restore();
  }

  @override
  void dispose() {
    _collapse.dispose();
    super.dispose();
  }

  static const _routes = [
    AppRoutes.home,
    AppRoutes.mealPlan,
    AppRoutes.trends,
    AppRoutes.profile,
  ];
  static const _destinations = [
    AppNavigationDestination(label: '首页', icon: AppIcons.home),
    AppNavigationDestination(label: '配餐', icon: AppIcons.bowlFood),
    AppNavigationDestination(label: '趋势', icon: AppIcons.trends),
    AppNavigationDestination(label: '我的', icon: AppIcons.profile),
  ];

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    final prefs = ref.watch(uiPreferencesProvider);
    final demo = ref.watch(demoProvider);
    void logout() {
      ref.invalidate(authGatewayProvider);
      ref.read(sessionProvider.notifier).clear();
    }

    final index =
        location.startsWith('/institution') ||
            location.startsWith(AppRoutes.mealPlan)
        ? 1
        : location.startsWith(AppRoutes.trends) ||
              location.startsWith(AppRoutes.reports)
        ? 2
        : location.startsWith(AppRoutes.profile) ||
              location == AppRoutes.settings
        ? 3
        : 0;
    void select(int selected) => context.go(_routes[selected]);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final padding = MediaQuery.paddingOf(context);
          final wide = constraints.maxWidth >= AppLayout.navigationBreakpoint;
          final showBottom = !wide && _routes.contains(location);
          final topHeight = AppLayout.topBarHeight(
            MediaQuery.textScalerOf(context),
          );
          final bottomWidth = math.min(
            AppLayout.bottomNavigationMaxWidth,
            constraints.maxWidth -
                padding.horizontal -
                AppLayout.mobileGutter * 2,
          );
          final bottomHeight = AppBottomNavigation.heightFor(
            context,
            width: bottomWidth,
            destinations: _destinations,
          );
          return GlassBackdrop(
            mode: wide || showBottom ? prefs.glassMode : GlassMode.off,
            reduceTransparency: prefs.reduceTransparency,
            background: AppPageScope(
              onBackFallback: () => context.go(AppRoutes.home),
              onLogout: logout,
              topInset: wide ? topHeight : 0,
              bottomInset: showBottom
                  ? bottomHeight + AppLayout.bottomNavigationMargin
                  : 0,
              child: NotificationListener<ScrollNotification>(
                onNotification: showBottom ? _collapse.handle : null,
                child: widget.child,
              ),
            ),
            overlay: Stack(
              children: [
                if (wide)
                  Positioned(
                    top: padding.top,
                    left: padding.left,
                    right: padding.right,
                    child: GlassSurface(
                      radius: 0,
                      mode: prefs.glassMode,
                      reduceTransparency: prefs.reduceTransparency,
                      child: SizedBox(
                        height: topHeight,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: AppLayout.maxPageWidth,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppLayout.wideGutter,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    AppIcons.bowlFood,
                                    size: 29,
                                    color: AppColors.primary,
                                  ),
                                  if (constraints.maxWidth >= 1000) ...[
                                    const SizedBox(width: 14),
                                    const Text(
                                      '膳食健康',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Center(
                                      child: AppTopNavigation(
                                        destinations: _destinations,
                                        selectedIndex: index,
                                        onSelected: select,
                                      ),
                                    ),
                                  ),
                                  if (constraints.maxWidth >= 1100) ...[
                                    const SizedBox(width: 16),
                                    TextButton(
                                      onPressed: () => context.push(
                                        demo.isInstitution
                                            ? AppRoutes.institutionMenu
                                            : AppRoutes.settings,
                                      ),
                                      child: Text(
                                        demo.isInstitution
                                            ? '医疗院 · 一号食堂'
                                            : '个人模式',
                                        style: AppTypography.body.copyWith(
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: '外观与演示设置',
                                    onPressed: () =>
                                        context.push(AppRoutes.settings),
                                    icon: const Icon(AppIcons.settings),
                                  ),
                                  PopupMenuButton<_AccountAction>(
                                    tooltip: '个人菜单',
                                    onSelected: (action) {
                                      switch (action) {
                                        case _AccountAction.profile:
                                          context.go(AppRoutes.profile);
                                        case _AccountAction.settings:
                                          context.push(AppRoutes.settings);
                                        case _AccountAction.logout:
                                          logout();
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: _AccountAction.profile,
                                        child: Text('我的'),
                                      ),
                                      PopupMenuItem(
                                        value: _AccountAction.settings,
                                        child: Text('外观与演示设置'),
                                      ),
                                      PopupMenuDivider(),
                                      PopupMenuItem(
                                        value: _AccountAction.logout,
                                        child: Text(
                                          '退出当前应用，不注销单点登录',
                                          style: TextStyle(
                                            color: AppColors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const AvatarIllustration(size: 40),
                                          if (constraints.maxWidth >= 1000) ...[
                                            const SizedBox(width: 10),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 88,
                                              ),
                                              child: Text(
                                                demo.profile.name,
                                                style: AppTypography.body,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showBottom)
                  Positioned(
                    left: AppLayout.mobileGutter + padding.left,
                    right: AppLayout.mobileGutter + padding.right,
                    bottom: AppLayout.bottomNavigationMargin + padding.bottom,
                    child: Center(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _collapse,
                        builder: (context, progress, _) => AppBottomNavigation(
                          destinations: _destinations,
                          selectedIndex: index,
                          onSelected: select,
                          collapseProgress: progress,
                          onExpand: _collapse.restore,
                          onInteractionChanged: (active) =>
                              _collapse.interacting = active,
                          glassMode: prefs.glassMode,
                          reduceTransparency: prefs.reduceTransparency,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _AccountAction { profile, settings, logout }
