import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';

class AppNavigationDestination {
  const AppNavigationDestination({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

/// 手机悬浮岛的展示层；路由选择仍由应用维护。
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });
  final List<AppNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static double heightFor(
    BuildContext context, {
    required double width,
    required List<AppNavigationDestination> destinations,
  }) {
    final labelWidth = math.max(
      1.0,
      math.min(75.0, (width - 24) / destinations.length) - 18,
    );
    var labelHeight = 0.0;
    for (final destination in destinations) {
      final painter = TextPainter(
        text: TextSpan(text: destination.label, style: _labelStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: labelWidth);
      labelHeight = math.max(labelHeight, painter.height);
      painter.dispose();
    }
    return math.max(
      AppLayout.bottomNavigationHeight,
      24 + 3 + labelHeight + 20,
    );
  }

  static const _labelStyle = TextStyle(fontSize: 12, height: 1.2);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = heightFor(
        context,
        width: constraints.maxWidth,
        destinations: destinations,
      );
      return SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 75,
                      height: height - 12,
                      child: Semantics(
                        selected: i == selectedIndex,
                        button: true,
                        child: Material(
                          color: i == selectedIndex
                              ? AppColors.navigationSelected
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => onSelected(i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    destinations[i].icon,
                                    size: 24,
                                    color: i == selectedIndex
                                        ? AppColors.primary
                                        : AppColors.muted,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    destinations[i].label,
                                    textAlign: TextAlign.center,
                                    style: _labelStyle.copyWith(
                                      fontWeight: i == selectedIndex
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: i == selectedIndex
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
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// 宽屏使用横向文字 tab，不复用手机的图标纵向布局。
class AppTopNavigation extends StatelessWidget {
  const AppTopNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });
  final List<AppNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < destinations.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Semantics(
            selected: i == selectedIndex,
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(96, 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                backgroundColor: i == selectedIndex
                    ? AppColors.greenSoft
                    : Colors.transparent,
                foregroundColor: i == selectedIndex
                    ? AppColors.primary
                    : AppColors.muted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () => onSelected(i),
              child: Text(destinations[i].label),
            ),
          ),
        ],
      ],
    ),
  );
}
