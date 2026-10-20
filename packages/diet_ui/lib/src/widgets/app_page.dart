import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import '../theme/app_typography.dart';

/// 导航覆盖量不含系统安全区，设计系统无需导入应用路由。
class AppPageScope extends InheritedWidget {
  const AppPageScope({
    super.key,
    required super.child,
    required this.onBackFallback,
    this.onLogout,
    this.bottomInset = 0,
    this.topInset = 0,
  });
  final VoidCallback onBackFallback;
  final VoidCallback? onLogout;
  final double bottomInset;
  final double topInset;
  static AppPageScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppPageScope>();
  @override
  bool updateShouldNotify(AppPageScope oldWidget) =>
      oldWidget.bottomInset != bottomInset ||
      oldWidget.topInset != topInset ||
      oldWidget.onLogout != onLogout ||
      oldWidget.onBackFallback != onBackFallback;
}

/// 标题与操作固定，只有业务内容滚动；页面统一消费系统安全区。
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.demoLabel = '设计样例 · 演示数据',
    required this.children,
    this.trailing,
    this.showBack = false,
    this.footer,
  });
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final String? demoLabel;
  final List<Widget> children;
  final Widget? trailing;
  final bool showBack;
  final Widget? footer;

  Widget _backButton(BuildContext context) => IconButton(
    tooltip: '返回',
    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    onPressed: () async {
      final popped = await Navigator.of(context).maybePop();
      if (!popped && context.mounted) {
        AppPageScope.of(context)?.onBackFallback();
      }
    },
    icon: const Icon(Icons.arrow_back),
  );

  Widget _titleBlock({required bool wide, bool centered = false}) => Column(
    crossAxisAlignment: centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    children: [
      if (eyebrow != null) ...[
        Text(eyebrow!, style: AppTypography.caption),
        const SizedBox(height: 4),
      ],
      Text(
        title,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: showBack && !wide
            ? AppTypography.secondaryTitle
            : AppTypography.pageTitle.copyWith(
                fontWeight: wide ? FontWeight.w600 : FontWeight.w700,
              ),
      ),
      if (subtitle != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            subtitle!,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: wide
                ? AppTypography.body.copyWith(color: AppColors.muted)
                : AppTypography.caption,
          ),
        ),
      if (demoLabel != null && !wide)
        Padding(
          padding: EdgeInsets.only(top: centered ? 8 : 4),
          child: Text(
            demoLabel!,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: AppTypography.small,
          ),
        ),
    ],
  );

  Widget _header(BuildContext context, {required bool wide}) {
    if (showBack && !wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(dimension: 44, child: _backButton(context)),
          const SizedBox(width: 8),
          Expanded(child: _titleBlock(wide: false, centered: true)),
          const SizedBox(width: 8),
          SizedBox(width: 44, child: trailing),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBack) ...[_backButton(context), const SizedBox(width: 8)],
        Expanded(child: _titleBlock(wide: wide)),
        if (wide && (demoLabel != null || trailing != null))
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 24, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (demoLabel != null)
                    Text(
                      demoLabel!,
                      textAlign: TextAlign.right,
                      style: AppTypography.caption,
                    ),
                  if (demoLabel != null && trailing != null)
                    const SizedBox(height: 8),
                  ?trailing,
                ],
              ),
            ),
          ),
        if (!wide && trailing != null)
          Padding(padding: const EdgeInsets.only(left: 12), child: trailing!),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppPageScope.of(context);
    final systemBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: footer != null,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= AppLayout.navigationBreakpoint;
                final gutter = AppLayout.pageGutter(constraints.maxWidth);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        (wide
                                ? 32
                                : showBack
                                ? 8
                                : 10) +
                            (scope?.topInset ?? 0),
                        gutter,
                        showBack && !wide ? 28 : 20,
                      ),
                      child: _header(context, wide: wide),
                    ),
                    Expanded(
                      child: ListView(
                        key: PageStorageKey(title),
                        padding: EdgeInsets.fromLTRB(
                          gutter,
                          0,
                          gutter,
                          footer == null
                              ? 24 + systemBottom + (scope?.bottomInset ?? 0)
                              : 24,
                        ),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        children: [
                          for (var i = 0; i < children.length; i++) ...[
                            children[i],
                            if (i < children.length - 1)
                              const SizedBox(height: AppLayout.sectionGap),
                          ],
                        ],
                      ),
                    ),
                    if (footer != null)
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          gutter,
                          12,
                          gutter,
                          16 + (scope?.bottomInset ?? 0),
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.canvas,
                          border: Border(
                            top: BorderSide(color: AppColors.line),
                          ),
                        ),
                        child: footer,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
