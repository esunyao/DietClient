import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import '../theme/app_typography.dart';

/// 圆角实体卡片容器，支持 `ListTile` 与水波纹交互并保持零阴影。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.radius = AppLayout.cardRadius,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: AppColors.line.withValues(alpha: 0.08));
    return Material(
      color: color ?? AppColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: border.top,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding.add(border.dimensions), child: child),
    );
  }
}

/// 分区标题行，可选右侧辅助文案或点击操作。
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.detail,
    this.onTap,
  });
  final String title;
  final String? detail;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Row(
      children: [
        Expanded(child: Text(title, style: AppTypography.sectionTitle)),
        if (detail != null) ...[
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
            child: onTap == null
                ? Text(detail!, style: AppTypography.caption)
                : TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      textStyle: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: onTap,
                    child: Text(detail!, textAlign: TextAlign.right),
                  ),
          ),
        ],
      ],
    ),
  );
}

/// 应用主/次按钮组件，支持前置图标与次要描边样式。
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    return secondary
        ? OutlinedButton(onPressed: onPressed, child: content)
        : FilledButton(onPressed: onPressed, child: content);
  }
}

/// 圆角状态徽标，[compact] 用于紧凑列表行样式。
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.color = AppColors.green,
    this.compact = false,
  });
  final String label;
  final Color color;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 4 : 5),
    decoration: BoxDecoration(
      color: color == AppColors.green
          ? AppColors.greenSoft
          : color == AppColors.amber
          ? AppColors.amberSoft
          : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: AppTypography.caption.copyWith(
        fontSize: compact ? 11 : 13,
        fontWeight: FontWeight.w500,
        color: color == AppColors.green
            ? AppColors.greenInk
            : color == AppColors.amber
            ? AppColors.amberInk
            : color,
      ),
    ),
  );
}

/// 指标展示卡片，支持单位与可选进度条。
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.color = AppColors.blue,
    this.progress,
  });
  final String label;
  final String value;
  final String? unit;
  final Color color;
  final double? progress;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 4,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            if (unit != null)
              Text(unit!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress!.clamp(0, 1),
            color: color,
            backgroundColor: color.withValues(alpha: 0.1),
            minHeight: 4,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ],
    ),
  );
}

/// 响应式分段选择器，支持等宽与实心高亮模式。
class AppSegmented extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.equalWidth = false,
    this.selectedFilled = false,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final bool equalWidth;
  final bool selectedFilled;

  @override
  Widget build(BuildContext context) {
    if (!equalWidth && !selectedFilled) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < labels.length; i++)
            ChoiceChip(
              label: Text(labels[i]),
              selected: i == selected,
              onSelected: (_) => onChanged(i),
              showCheckmark: false,
              selectedColor: AppColors.blueSoft,
              labelStyle: TextStyle(
                color: i == selected ? AppColors.blue : AppColors.muted,
              ),
              side: BorderSide(
                color: i == selected
                    ? AppColors.blue.withValues(alpha: 0.3)
                    : AppColors.line,
              ),
            ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const style = TextStyle(fontSize: 14, height: 1.4);
        var minWidth = 44.0;
        for (final label in labels) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          minWidth = math.max(minWidth, painter.width + 18);
          painter.dispose();
        }
        final available = constraints.maxWidth - 8;
        final perRow = ((available + 4) / (minWidth + 4)).floor().clamp(
          1,
          math.max(1, labels.length),
        );
        final width = (available - (perRow - 1) * 4) / perRow;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: selectedFilled ? Colors.transparent : AppColors.greenSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (var i = 0; i < labels.length; i++)
                  SizedBox(
                    width: equalWidth ? width : null,
                    child: Semantics(
                      selected: i == selected,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          backgroundColor: i == selected
                              ? selectedFilled
                                    ? AppColors.primary
                                    : AppColors.surface
                              : selectedFilled
                              ? AppColors.surface
                              : Colors.transparent,
                          foregroundColor: i == selected && selectedFilled
                              ? Colors.white
                              : i == selected
                              ? AppColors.primary
                              : AppColors.muted,
                          textStyle: style.copyWith(
                            fontWeight: i == selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => onChanged(i),
                        child: Text(labels[i], textAlign: TextAlign.center),
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
}

/// 柔和提示横幅卡片。
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.color,
  });
  final String text;
  final IconData icon;
  final Color? color;
  @override
  Widget build(BuildContext context) => AppCard(
    color: (color ?? AppColors.blue).withValues(alpha: 0.08),
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color ?? AppColors.blue, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.ink),
          ),
        ),
      ],
    ),
  );
}

/// 替换当前提示并展示底部简短操作反馈消息。
void showDemoMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
