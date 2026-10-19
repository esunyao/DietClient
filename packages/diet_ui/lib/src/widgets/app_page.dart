import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 页面布局不依赖应用路由；无返回栈时由应用外壳提供首页恢复入口。
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.trailing,
    this.showBack = false,
    this.footer,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? trailing;
  final bool showBack;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.canvas,
    bottomNavigationBar: footer == null
        ? null
        : SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              decoration: const BoxDecoration(
                color: AppColors.canvas,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Align(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1130),
                  child: SizedBox(width: double.infinity, child: footer),
                ),
              ),
            ),
          ),
    body: SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1194),
          child: ListView(
            key: PageStorageKey(title),
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width >= 840 ? 32 : 24,
              24,
              MediaQuery.sizeOf(context).width >= 840 ? 32 : 24,
              32,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showBack)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        tooltip: '返回',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontSize: showBack ? 23 : 28),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              subtitle!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: trailing!,
                    ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 12, bottom: 20),
                child: Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 15,
                      color: AppColors.muted,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'UI 演示 · 示例数据与操作仅保留在内存',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
