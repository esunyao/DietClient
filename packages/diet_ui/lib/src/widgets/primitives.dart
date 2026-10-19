import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.line.withValues(alpha: 0.08)),
    ),
    child: child,
  );
}

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
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 4,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      if (detail != null)
        onTap == null
            ? Text(detail!, style: Theme.of(context).textTheme.bodySmall)
            : TextButton(onPressed: onTap, child: Text(detail!)),
    ],
  );
}

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

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.color = AppColors.green,
  });
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color == AppColors.green
            ? AppColors.greenInk
            : color == AppColors.amber
            ? AppColors.amberInk
            : color,
      ),
    ),
  );
}

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

class AppSegmented extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
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

void showDemoMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
