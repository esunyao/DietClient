import 'dart:math' as math;

import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/ui_preview_config.dart';
import '../core/presentation/account_identity.dart';
import '../core/presentation/app_routes.dart';
import '../core/presentation/display_state.dart';
import '../core/presentation/navigation_manager.dart';
import '../core/presentation/ui_preferences.dart';
import '../core/session/session_controller.dart';
import '../demo/demo_store.dart';
import 'app_manager.dart';
import 'navigation_collapse_controller.dart';

/// 业务页面共享外壳，统一装配玻璃背景、响应式导航栏与账户菜单入口。
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _collapse = NavigationCollapseController();
  bool _menuOpen = false;

  static const _destinations = [
    AppNavigationDestination(label: '首页', icon: AppIcons.home),
    AppNavigationDestination(label: '配餐', icon: AppIcons.bowlFood),
    AppNavigationDestination(label: '趋势', icon: AppIcons.trends),
    AppNavigationDestination(label: '我的', icon: AppIcons.profile),
  ];

  @override
  void initState() {
    super.initState();
    ref.listenManual<String?>(sessionNoticeProvider, (_, notice) {
      if (notice == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(notice)));
      });
    }, fireImmediately: true);
  }

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

  void _openSettings() =>
      ref.read(navigationManagerProvider).openSettingsGuarded(context);

  void _logout() => ref.read(appLifecycleManagerProvider).signOut();

  void _selectDestination(int index) =>
      ref.read(navigationManagerProvider).goTab(context, index);

  void _openModeEntry(bool institution) {
    final navigation = ref.read(navigationManagerProvider);
    if (institution) {
      navigation.openInstitutionMenuGuarded(context);
    } else {
      navigation.openSettingsGuarded(context);
    }
  }

  void _handleAccountAction(_AccountAction action) {
    switch (action) {
      case _AccountAction.profile:
        ref.read(navigationManagerProvider).goProfile(context);
      case _AccountAction.settings:
        _openSettings();
      case _AccountAction.logout:
        _logout();
    }
  }

  void _setMenuOpen(bool value) => setState(() => _menuOpen = value);

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    final prefs = ref.watch(uiPreferencesProvider);
    final uiPreview = ref.watch(uiPreviewProvider);
    final demo = uiPreview ? ref.watch(demoProvider) : null;
    final institution = uiPreview
        ? demo!.isInstitution
        : ref.watch(displayStateProvider).isInstitution;
    final accountName = uiPreview
        ? demo!.profile.name
        : ref.watch(accountIdentityProvider).asData?.value.name ?? '当前账户';
    final selectedIndex = AppRoutes.tabIndexFor(location);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) => _buildShellLayout(
          context,
          constraints,
          location: location,
          selectedIndex: selectedIndex,
          prefs: prefs,
          uiPreview: uiPreview,
          institution: institution,
          accountName: accountName,
        ),
      ),
    );
  }

  Widget _buildShellLayout(
    BuildContext context,
    BoxConstraints constraints, {
    required String location,
    required int selectedIndex,
    required UiPreferences prefs,
    required bool uiPreview,
    required bool institution,
    required String accountName,
  }) {
    final padding = MediaQuery.paddingOf(context);
    final wide = constraints.maxWidth >= AppLayout.navigationBreakpoint;
    final sidebar =
        wide && (kIsWeb || defaultTargetPlatform == TargetPlatform.windows);
    final showBottom = !wide && AppRoutes.isPrimaryTab(location);
    final topHeight = AppLayout.topBarHeight(MediaQuery.textScalerOf(context));
    final bottomWidth = math.min(
      AppLayout.bottomNavigationMaxWidth,
      constraints.maxWidth - padding.horizontal - AppLayout.mobileGutter * 2,
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
        onBackFallback: () =>
            ref.read(navigationManagerProvider).goHome(context),
        onLogout: uiPreview ? null : _logout,
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
              if (uiPreview) const _PreviewModeStrip(),
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
                selectedIndex: selectedIndex,
                onSelected: _selectDestination,
                onSettings: _openSettings,
                glassMode: prefs.glassMode,
                reduceTransparency: prefs.reduceTransparency,
                menuOpen: _menuOpen,
                accountBuilder: (expansion) => _SideAccountMenu(
                  expansion: expansion,
                  accountName: accountName,
                  uiPreview: uiPreview,
                  onMenuOpenChanged: _setMenuOpen,
                  onAction: _handleAccountAction,
                ),
              ),
            ),
          if (wide && !sidebar)
            Positioned(
              top: padding.top,
              left: padding.left,
              right: padding.right,
              child: _WideTopNavigationBar(
                maxWidth: constraints.maxWidth,
                topHeight: topHeight,
                destinations: _destinations,
                selectedIndex: selectedIndex,
                institution: institution,
                uiPreview: uiPreview,
                accountName: accountName,
                glassMode: prefs.glassMode,
                reduceTransparency: prefs.reduceTransparency,
                onSelect: _selectDestination,
                onOpenSettings: _openSettings,
                onOpenModeEntry: () => _openModeEntry(institution),
                onAccountAction: _handleAccountAction,
              ),
            ),
          if (showBottom)
            _BottomNavigationOverlay(
              padding: padding,
              collapse: _collapse,
              destinations: _destinations,
              selectedIndex: selectedIndex,
              glassMode: prefs.glassMode,
              reduceTransparency: prefs.reduceTransparency,
              onSelect: _selectDestination,
            ),
        ],
      ),
    );
  }
}

class _PreviewModeStrip extends StatelessWidget {
  const _PreviewModeStrip();

  @override
  Widget build(BuildContext context) => const SafeArea(
    bottom: false,
    child: Padding(
      padding: EdgeInsets.all(8),
      child: Text('Web UI 预览 · 未登录', style: AppTypography.small),
    ),
  );
}

class _SideAccountMenu extends StatelessWidget {
  const _SideAccountMenu({
    required this.expansion,
    required this.accountName,
    required this.uiPreview,
    required this.onMenuOpenChanged,
    required this.onAction,
  });

  final double expansion;
  final String accountName;
  final bool uiPreview;
  final ValueChanged<bool> onMenuOpenChanged;
  final ValueChanged<_AccountAction> onAction;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_AccountAction>(
    tooltip: '个人菜单',
    onOpened: () => onMenuOpenChanged(true),
    onCanceled: () => onMenuOpenChanged(false),
    onSelected: (action) {
      onMenuOpenChanged(false);
      onAction(action);
    },
    itemBuilder: (_) => _buildAccountMenuItems(uiPreview, coloredLogout: false),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRect(
        child: SizedBox(
          height: math.max(
            36,
            MediaQuery.textScalerOf(context).scale(14) * 1.5,
          ),
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.directional(
                textDirection: Directionality.of(context),
                start: 10 * (1 - expansion),
                top: 0,
                bottom: 0,
                child: const Center(child: AccountAvatar(size: 36)),
              ),
              Positioned.directional(
                textDirection: Directionality.of(context),
                start: 46,
                top: 0,
                bottom: 0,
                width: 130,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ExcludeSemantics(
                    excluding: expansion <= .3,
                    child: Opacity(
                      opacity: ((expansion - .3) / .5).clamp(0.0, 1.0),
                      child: SizedBox(
                        width: 130,
                        child: Text(
                          accountName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
  );
}

class _WideTopNavigationBar extends StatelessWidget {
  const _WideTopNavigationBar({
    required this.maxWidth,
    required this.topHeight,
    required this.destinations,
    required this.selectedIndex,
    required this.institution,
    required this.uiPreview,
    required this.accountName,
    required this.glassMode,
    required this.reduceTransparency,
    required this.onSelect,
    required this.onOpenSettings,
    required this.onOpenModeEntry,
    required this.onAccountAction,
  });

  final double maxWidth;
  final double topHeight;
  final List<AppNavigationDestination> destinations;
  final int selectedIndex;
  final bool institution;
  final bool uiPreview;
  final String accountName;
  final GlassMode glassMode;
  final bool reduceTransparency;
  final ValueChanged<int> onSelect;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenModeEntry;
  final ValueChanged<_AccountAction> onAccountAction;

  @override
  Widget build(BuildContext context) => GlassSurface(
    radius: 0,
    mode: glassMode,
    reduceTransparency: reduceTransparency,
    child: SizedBox(
      height: topHeight,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
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
                if (maxWidth >= 1000) ...[
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
                      destinations: destinations,
                      selectedIndex: selectedIndex,
                      onSelected: onSelect,
                    ),
                  ),
                ),
                if (maxWidth >= 1100) ...[
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: onOpenModeEntry,
                    child: Text(
                      institution
                          ? (uiPreview ? '医疗院 · 一号食堂' : '机构内个人模式')
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
                  onPressed: onOpenSettings,
                  icon: const Icon(AppIcons.settings),
                ),
                PopupMenuButton<_AccountAction>(
                  tooltip: '个人菜单',
                  onSelected: onAccountAction,
                  itemBuilder: (_) =>
                      _buildAccountMenuItems(uiPreview, coloredLogout: true),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AccountAvatar(size: 40),
                        if (maxWidth >= 1000) ...[
                          const SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 88),
                            child: Text(accountName, style: AppTypography.body),
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
  );
}

class _BottomNavigationOverlay extends StatelessWidget {
  const _BottomNavigationOverlay({
    required this.padding,
    required this.collapse,
    required this.destinations,
    required this.selectedIndex,
    required this.glassMode,
    required this.reduceTransparency,
    required this.onSelect,
  });

  final EdgeInsets padding;
  final NavigationCollapseController collapse;
  final List<AppNavigationDestination> destinations;
  final int selectedIndex;
  final GlassMode glassMode;
  final bool reduceTransparency;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Positioned(
    left: AppLayout.mobileGutter + padding.left,
    right: AppLayout.mobileGutter + padding.right,
    bottom: AppLayout.bottomNavigationMargin + padding.bottom,
    child: Center(
      child: ValueListenableBuilder<double>(
        valueListenable: collapse,
        builder: (context, progress, _) => AppBottomNavigation(
          destinations: destinations,
          selectedIndex: selectedIndex,
          onSelected: onSelect,
          collapseProgress: progress,
          onExpand: collapse.restore,
          onInteractionChanged: (active) => collapse.interacting = active,
          glassMode: glassMode,
          reduceTransparency: reduceTransparency,
        ),
      ),
    ),
  );
}

List<PopupMenuEntry<_AccountAction>> _buildAccountMenuItems(
  bool uiPreview, {
  required bool coloredLogout,
}) => [
  const PopupMenuItem(value: _AccountAction.profile, child: Text('我的')),
  const PopupMenuItem(value: _AccountAction.settings, child: Text('应用设置')),
  if (!uiPreview && coloredLogout) const PopupMenuDivider(),
  if (!uiPreview)
    PopupMenuItem(
      value: _AccountAction.logout,
      child: Text(
        '退出当前应用，不注销单点登录',
        style: coloredLogout ? const TextStyle(color: AppColors.red) : null,
      ),
    ),
];

enum _AccountAction { profile, settings, logout }
