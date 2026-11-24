import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';

import '../../../../demo/demo_store.dart';

/// 格式化演示餐食日期为 `YYYY-MM-DD`。
String mealDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 格式化演示餐食时间为 `HH:mm`。
String mealTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// 演示餐食列表行组件，支持分析状态标签及宽屏选中态。
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
            final status = _MealStatusColumn(meal: meal, stacked: stacked);
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

class _MealStatusColumn extends StatelessWidget {
  const _MealStatusColumn({required this.meal, required this.stacked});

  final MealEntry meal;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final ready = meal.status == AnalysisStatus.ready;
    return Column(
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
  }
}

/// 演示整餐营养详情卡片，未填指标保持未知且评分为暂未评估。
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
              child: _EnergyHeadline(
                energy: nutrients.energy,
                title: expanded ? null : title,
              ),
            ),
            if (showScore && !expanded)
              const Expanded(flex: 2, child: _ScorePlaceholder()),
          ],
        ),
        if (expanded) const SizedBox(height: 28) else const Divider(height: 28),
        _MacroNutrientGrid(nutrients: nutrients),
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

class _EnergyHeadline extends StatelessWidget {
  const _EnergyHeadline({required this.energy, required this.title});

  final double? energy;
  final String? title;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (title != null) ...[
        Text(
          title!,
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 8),
      ],
      Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Text(
            formatAmount(energy),
            style: const TextStyle(
              fontSize: 39,
              height: 1.12,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (energy != null)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'kcal',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ),
        ],
      ),
    ],
  );
}

class _ScorePlaceholder extends StatelessWidget {
  const _ScorePlaceholder();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('膳食评分', style: TextStyle(color: AppColors.muted, fontSize: 13)),
      SizedBox(height: 8),
      Text('暂未评估', style: TextStyle(color: AppColors.muted, fontSize: 17)),
    ],
  );
}

class _MacroNutrientGrid extends StatelessWidget {
  const _MacroNutrientGrid({required this.nutrients});

  final Nutrients nutrients;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // 测量当前文字缩放下的数值宽度，动态决定每行可容纳的列数。
      var minimum = 68.0;
      for (final value in [nutrients.protein, nutrients.carbs, nutrients.fat]) {
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
            _MacroCell(width: width, label: item.$1, value: item.$2),
        ],
      );
    },
  );
}

class _MacroCell extends StatelessWidget {
  const _MacroCell({
    required this.width,
    required this.label,
    required this.value,
  });

  final double width;
  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(
              formatAmount(value),
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if (value != null)
              const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text(
                  'g',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ],
    ),
  );
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
