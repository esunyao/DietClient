import 'package:flutter/material.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/demo/demo_store.dart';

String mealDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String mealTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class MealRow extends StatelessWidget {
  const MealRow({
    super.key,
    required this.meal,
    required this.onTap,
    this.selected = false,
    this.embedded = false,
  });
  final MealEntry meal;
  final VoidCallback onTap;
  final bool selected;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final ready = meal.status == AnalysisStatus.ready;
    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth <
                300 * MediaQuery.textScalerOf(context).scale(14) / 14;
            final status = Column(
              crossAxisAlignment: stacked
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Text(
                  ready
                      ? '${formatAmount(meal.nutrients.energy)}${meal.nutrients.energy == null ? '' : ' kcal'}'
                      : meal.status == AnalysisStatus.failed
                      ? '分析失败'
                      : '待分析',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                AppBadge(
                  label: meal.status.label,
                  color: ready ? AppColors.primary : AppColors.amberInk,
                ),
              ],
            );
            return Row(
              crossAxisAlignment: stacked
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const PlateIllustration(size: 46),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            meal.type.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            mealTime(meal.consumedAt),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meal.title,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        meal.source.label,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      if (!meal.confirmed)
                        const Text(
                          '待确认，尚未计入摄入',
                          style: TextStyle(
                            color: AppColors.amberInk,
                            fontSize: 12,
                          ),
                        ),
                      if (stacked) ...[const SizedBox(height: 10), status],
                    ],
                  ),
                ),
                if (!stacked) ...[const SizedBox(width: 10), status],
              ],
            );
          },
        ),
      ),
    );
    if (embedded) {
      return Material(
        color: selected ? AppColors.greenSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    }
    return AppCard(
      radius: 16,
      padding: EdgeInsets.zero,
      color: selected ? AppColors.greenSoft : null,
      child: content,
    );
  }
}

class MealNutrients extends StatelessWidget {
  const MealNutrients({
    super.key,
    required this.nutrients,
    this.title = '本餐能量',
    this.showScore = true,
    this.embedded = false,
    this.expanded = false,
    this.leading,
  });
  final Nutrients nutrients;
  final String? title;
  final bool showScore;
  final bool embedded;
  final bool expanded;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (expanded) ...[
          const Text(
            '整餐营养',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 22),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 16)],
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null && !expanded) ...[
                    Text(
                      title!,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      Text(
                        formatAmount(nutrients.energy),
                        style: const TextStyle(
                          fontSize: 39,
                          height: 1.12,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (nutrients.energy != null)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            'kcal',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (showScore && !expanded)
              const Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '膳食评分',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '暂未评估',
                      style: TextStyle(color: AppColors.muted, fontSize: 17),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (expanded) const SizedBox(height: 28) else const Divider(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            var minimum = 68.0;
            for (final value in [
              nutrients.protein,
              nutrients.carbs,
              nutrients.fat,
            ]) {
              final painter = TextPainter(
                text: TextSpan(
                  text: '${formatAmount(value)}${value == null ? '' : ' g'}',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              if (painter.width > minimum) minimum = painter.width;
              painter.dispose();
            }
            final perRow = ((constraints.maxWidth + 12) / (minimum + 12))
                .floor()
                .clamp(1, 3);
            final width = (constraints.maxWidth - 12 * (perRow - 1)) / perRow;
            return Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                for (final item in [
                  ('蛋白质', nutrients.protein),
                  ('碳水', nutrients.carbs),
                  ('脂肪', nutrients.fat),
                ])
                  SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.end,
                          children: [
                            Text(
                              formatAmount(item.$2),
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            if (item.$2 != null)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 3),
                                child: Text(
                                  'g',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        if (expanded) const Divider(height: 36) else const SizedBox(height: 14),
        if (!expanded && nutrients.sodium == null && nutrients.fiber == null)
          const Text(
            '钠、膳食纤维：暂无可靠数据',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          )
        else ...[
          _NutrientLine(label: '钠', value: nutrients.sodium, unit: 'mg'),
          const SizedBox(height: 12),
          _NutrientLine(label: '膳食纤维', value: nutrients.fiber, unit: 'g'),
        ],
        if (expanded && showScore) ...[
          const SizedBox(height: 24),
          const Row(
            children: [
              Expanded(
                child: Text(
                  '膳食评分',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
              Text(
                '暂未评估',
                style: TextStyle(color: AppColors.muted, fontSize: 16),
              ),
            ],
          ),
        ],
      ],
    );
    return embedded
        ? content
        : AppCard(
            radius: expanded ? 16 : 20,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: content,
          );
  }
}

class _NutrientLine extends StatelessWidget {
  const _NutrientLine({
    required this.label,
    required this.value,
    required this.unit,
  });
  final String label;
  final double? value;
  final String unit;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ),
      Text(
        value == null ? '暂无可靠数据' : '${formatAmount(value)} $unit',
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
    ],
  );
}
