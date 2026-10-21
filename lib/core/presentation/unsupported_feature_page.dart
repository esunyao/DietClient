import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

/// 真实模式没有服务契约的入口，不展示虚构记录或执行模拟写入。
class UnsupportedFeaturePage extends StatelessWidget {
  const UnsupportedFeaturePage({
    super.key,
    required this.title,
    required this.description,
    this.showBack = true,
  });

  final String title;
  final String description;
  final bool showBack;

  @override
  Widget build(BuildContext context) => AppPage(
    title: title,
    demoLabel: null,
    showBack: showBack,
    children: [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading(title: '暂未支持'),
            const SizedBox(height: 12),
            Text(description),
            const SizedBox(height: 20),
            AppButton(
              label: '查看饮食记录',
              secondary: true,
              onPressed: () => context.go(AppRoutes.mealHistory),
            ),
          ],
        ),
      ),
    ],
  );
}
