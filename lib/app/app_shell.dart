import 'dart:math' as math;

import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'navigation_collapse_controller.dart';
import '../core/config/ui_preview_config.dart';
import '../core/presentation/app_routes.dart';
import '../core/presentation/account_identity.dart';
import '../core/presentation/ui_preferences.dart';
import '../core/presentation/display_state.dart';
import '../core/presentation/unsaved_form.dart';
import '../core/session/session_controller.dart';
import '../demo/demo_store.dart';
import '../features/auth/application/login_controller.dart';

/// @brief 为业务页面装配共享背景、响应式导航和账户入口。
/// @details 页面内容由路由提供。
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    // 会话提示在下一帧展示；回调执行前需确认外壳仍存活。
    ref.listenManual<String?>(sessionNoticeProvider, (_, notice) {
      if (notice == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(notice)));
      });
    }, fireImmediately: true);
  }

  final _collapse = NavigationCollapseController();
  bool _menuOpen = false;

  /// @brief 在路径变化时恢复展开底部导航栏。
  /// @param oldWidget 更新前的旧组件实例。
  /// @note 收起控制器随外壳组件销毁而释放。
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
    // 预览读取演示模式与姓名，正常路径读取真实展示状态和共享账户身份。
    final uiPreview = ref.watch(uiPreviewProvider);
    final demo = uiPreview ? ref.watch(demoProvider) : null;
    final institution = uiPreview
        ? demo!.isInstitution
        : ref.watch(displayStateProvider).isInstitution;
    final accountName = uiPreview
        ? demo!.profile.name
        : ref.watch(accountIdentityProvider).asData?.value.name ?? '当前账户';
    // 保存等离开保护忙碌时不打开设置；退出只清理当前应用会话。
    void openSettings() {
      if (!ref.read(routeLeaveRegistryProvider).busy) {
        context.push(AppRoutes.settings);
      }
    }

    void logout() {
      ref.invalidate(authGatewayProvider);
      ref.read(sessionProvider.notifier).clear();
    }

    // 将机构、配餐、趋势、报告及个人相关的指定路径映射到主入口；未匹配时高亮首页。
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
          // 宽屏在 Web/Windows 使用侧栏，其他平台使用顶栏；窄屏仅主路径显示底栏。
          final wide = constraints.maxWidth >= AppLayout.navigationBreakpoint;
          final sidebar =
              wide &&
              (kIsWeb || defaultTargetPlatform == TargetPlatform.windows);
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
          // 背景只装配一次，导航作为覆盖层；页面 inset 不包含系统安全区。
          // 侧栏正文固定预留 120，展开部分覆盖正文而非再次挤压。
          return GlassBackdrop(
            mode: wide || showBottom ? prefs.glassMode : GlassMode.off,
            reduceTransparency: prefs.reduceTransparency,
            background: AppPageScope(
              onBackFallback: () => context.go(AppRoutes.home),
              onLogout: uiPreview ? null : logout,
              uiPreview: uiPreview,
              topInset: sidebar
                  ? 0
                  : wide
                  ? topHeight
                  : 0,
              bottomInset: showBottom
                  ? bottomHeight + AppLayout.bottomNavigationMargin
                  : 0,
              child: Padding(
                padding: EdgeInsets.only(left: sidebar ? 120 : 0),
                child: Column(
                  children: [
                    if (uiPreview)
                      const SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'Web UI 预览 · 未登录',
                            style: AppTypography.small,
                          ),
                        ),
                      ),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: showBottom ? _collapse.handle : null,
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            overlay: Stack(
              children: [
                if (sidebar)
                  Positioned(
                    top: padding.top + 12,
                    bottom: padding.bottom + 12,
                    left: padding.left + 12,
                    child: AppSideNavigation(
                      destinations: _destinations,
                      selectedIndex: index,
                      onSelected: select,
                      onSettings: openSettings,
                      glassMode: prefs.glassMode,
                      reduceTransparency: prefs.reduceTransparency,
                      menuOpen: _menuOpen,
                      // 用连续展开进度移动头像并淡入姓名，菜单开关状态交给侧栏。
                      accountBuilder: (expansion) =>
                          PopupMenuButton<_AccountAction>(
                            tooltip: '个人菜单',
                            onOpened: () => setState(() => _menuOpen = true),
                            onCanceled: () => setState(() => _menuOpen = false),
                            onSelected: (action) {
                              setState(() => _menuOpen = false);
                              switch (action) {
                                case _AccountAction.profile:
                                  context.go(AppRoutes.profile);
                                case _AccountAction.settings:
                                  openSettings();
                                case _AccountAction.logout:
                                  logout();
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: _AccountAction.profile,
                                child: Text('我的'),
                              ),
                              const PopupMenuItem(
                                value: _AccountAction.settings,
                                child: Text('应用设置'),
                              ),
                              if (!uiPreview)
                                const PopupMenuItem(
                                  value: _AccountAction.logout,
                                  child: Text('退出当前应用，不注销单点登录'),
                                ),
                            ],
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: ClipRect(
                                child: SizedBox(
                                  height: math.max(
                                    36,
                                    MediaQuery.textScalerOf(context).scale(14) *
                                        1.5,
                                  ),
                                  width: double.infinity,
                                  child: Stack(
                                    children: [
                                      Positioned.directional(
                                        textDirection: Directionality.of(
                                          context,
                                        ),
                                        start: 10 * (1 - expansion),
                                        top: 0,
                                        bottom: 0,
                                        child: const Center(
                                          child: AccountAvatar(size: 36),
                                        ),
                                      ),
                                      Positioned.directional(
                                        textDirection: Directionality.of(
                                          context,
                                        ),
                                        start: 46,
                                        top: 0,
                                        bottom: 0,
                                        width: 130,
                                        child: Align(
                                          alignment:
                                              AlignmentDirectional.centerStart,
                                          child: ExcludeSemantics(
                                            excluding: expansion <= .3,
                                            child: Opacity(
                                              opacity: ((expansion - .3) / .5)
                                                  .clamp(0.0, 1.0),
                                              child: SizedBox(
                                                width: 130,
                                                child: Text(
                                                  accountName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AppTypography.body,
                                                ),
                                              ),
                                            ),
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
                if (wide && !sidebar)
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
                                      onPressed: () {
                                        if (institution) {
                                          if (!ref
                                              .read(routeLeaveRegistryProvider)
                                              .busy) {
                                            context.push(
                                              AppRoutes.institutionMenu,
                                            );
                                          }
                                        } else {
                                          openSettings();
                                        }
                                      },
                                      child: Text(
                                        institution
                                            ? (uiPreview
                                                  ? '医疗院 · 一号食堂'
                                                  : '机构内个人模式')
                                            : '个人模式',
                                        style: AppTypography.body.copyWith(
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: '应用设置',
                                    onPressed: openSettings,
                                    icon: const Icon(AppIcons.settings),
                                  ),
                                  PopupMenuButton<_AccountAction>(
                                    tooltip: '个人菜单',
                                    onSelected: (action) {
                                      switch (action) {
                                        case _AccountAction.profile:
                                          context.go(AppRoutes.profile);
                                        case _AccountAction.settings:
                                          openSettings();
                                        case _AccountAction.logout:
                                          logout();
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: _AccountAction.profile,
                                        child: Text('我的'),
                                      ),
                                      PopupMenuItem(
                                        value: _AccountAction.settings,
                                        child: Text('应用设置'),
                                      ),
                                      if (!uiPreview) const PopupMenuDivider(),
                                      if (!uiPreview)
                                        const PopupMenuItem(
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
                                          const AccountAvatar(size: 40),
                                          if (constraints.maxWidth >= 1000) ...[
                                            const SizedBox(width: 10),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 88,
                                              ),
                                              child: Text(
                                                accountName,
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
                // 主体滚动驱动底栏收起，导航交互期间由控制器暂停收起。
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
