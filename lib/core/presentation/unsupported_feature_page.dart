import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'navigation_manager.dart';

/// 暂未支持功能提示页，用于无公开后端契约的原生入口，不虚构记录或写入结果。
class UnsupportedFeaturePage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
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
              onPressed: () =>
                  ref.read(navigationManagerProvider).goMealHistory(context),
            ),
          ],
        ),
      ),
    ],
  );
}
