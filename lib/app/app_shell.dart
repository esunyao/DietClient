import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/presentation/app_routes.dart';
import '../core/presentation/ui_preferences.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(uiPreferencesProvider);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final routes = [
      AppRoutes.home,
      AppRoutes.mealPlan,
      AppRoutes.trends,
      AppRoutes.profile,
    ];
    final labels = ['首页', '配餐', '趋势', '我的'];
    final icons = [
      AppIcons.home,
      AppIcons.plan,
      AppIcons.trends,
      AppIcons.profile,
    ];
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
    final showBottom = !wide && routes.contains(location);
    Widget navigation() => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < routes.length; i++)
          Expanded(
            child: Semantics(
              selected: i == index,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.go(routes[i]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 9,
                    horizontal: 4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icons[i],
                        size: 22,
                        color: i == index ? AppColors.primary : AppColors.muted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: i == index
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: i == index
                              ? AppColors.primary
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    final glass = GlassSurface(
      mode: prefs.glassMode,
      reduceTransparency: prefs.reduceTransparency,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: navigation(),
      ),
    );
    return Scaffold(
      body: Column(
        children: [
          if (wide)
            SafeArea(
              bottom: false,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1194),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Text(
                      '膳食健康',
                      style: TextStyle(
                        fontSize: 20,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(width: 370, child: glass),
                    const SizedBox(width: 18),
                    IconButton(
                      tooltip: '外观与演示设置',
                      onPressed: () => context.push(AppRoutes.settings),
                      icon: const Icon(Icons.tune),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: showBottom
                          ? 96 + MediaQuery.paddingOf(context).bottom
                          : 0,
                    ),
                    child: child,
                  ),
                ),
                if (showBottom)
                  Positioned(
                    left: 28,
                    right: 28,
                    bottom: 16 + MediaQuery.paddingOf(context).bottom,
                    child: Align(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: glass,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
