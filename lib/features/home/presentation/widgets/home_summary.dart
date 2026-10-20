import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/app_routes.dart';
import '../../../../demo/demo_store.dart';

String homeAmount(double? value) => formatAmount(
  value,
  unknown: '—',
).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

class HomeNutritionSummary extends StatelessWidget {
  const HomeNutritionSummary({
    super.key,
    required this.data,
    this.wide = false,
  });

  final DemoSnapshot data;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final meals = data.todayMeals;
    final ready = meals
        .where((meal) => meal.confirmed && meal.status == AnalysisStatus.ready)
        .length;
    final analyzing = meals
        .where((meal) => meal.status == AnalysisStatus.analyzing)
        .length;
    final summary = '$ready餐已分析 · $analyzing餐分析中';
    final total = data.todayTotal;
    final energy = Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 8,
      children: [
        Text(
          homeAmount(total.energy),
          style: const TextStyle(
            fontSize: 39,
            fontWeight: FontWeight.w700,
            height: 1.2,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 5),
          child: Text(
            'kcal',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        ),
      ],
    );
    final target = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.greenSoft,
        foregroundColor: AppColors.primary,
        minimumSize: const Size(113, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      onPressed: () => context.push(AppRoutes.healthRecords),
      child: const Text('设置目标'),
    );
    final nutrients = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Nutrient(label: '蛋白质', value: total.protein),
        ),
        if (wide) const _NutrientDivider(),
        Expanded(
          child: _Nutrient(label: '碳水', value: total.carbs),
        ),
        if (wide) const _NutrientDivider(),
        Expanded(
          child: _Nutrient(label: '脂肪', value: total.fat),
        ),
      ],
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: wide ? 210 : 220),
      child: AppCard(
        radius: wide ? 16 : 20,
        padding: EdgeInsets.fromLTRB(
          wide ? 24 : 20,
          wide ? 20 : 16,
          wide ? 24 : 20,
          wide ? 0 : 5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '今日已记录营养',
                    style: TextStyle(
                      fontSize: wide ? 18 : 17,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    wide ? summary : '暂未评估',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: wide ? 13 : 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            if (!wide) ...[
              const SizedBox(height: 5),
              Text(
                summary,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 310 ||
                      MediaQuery.textScalerOf(context).scale(14) > 18) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [energy, const SizedBox(height: 8), target],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: energy),
                      const SizedBox(width: 8),
                      target,
                    ],
                  );
                },
              ),
              const Divider(height: 16),
              nutrients,
              const SizedBox(height: 4),
              const Text(
                '仅汇总已确认的已分析记录，不代表全天摄入',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ] else ...[
              const SizedBox(height: 15),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: energy),
                  const SizedBox(width: 20),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '膳食评价',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 14,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          '暂未评估',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 18,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              nutrients,
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '当前记录不完整，不代表全天摄入',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => context.push(AppRoutes.healthRecords),
                    child: const Text('设置营养目标', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Nutrient extends StatelessWidget {
  const _Nutrient({required this.label, required this.value});
  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          height: 1.2,
        ),
      ),
      const SizedBox(height: 6),
      Text.rich(
        TextSpan(
          text: homeAmount(value),
          children: const [
            TextSpan(
              text: ' g',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.2,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

class _NutrientDivider extends StatelessWidget {
  const _NutrientDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 51,
    margin: const EdgeInsets.only(right: 16),
    color: AppColors.line,
  );
}

class HomeMeals extends StatelessWidget {
  const HomeMeals({super.key, required this.meals, this.wide = false});
  final List<MealEntry> meals;
  final bool wide;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '今天吃了什么',
              style: TextStyle(
                fontSize: wide ? 20 : 19,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.push(AppRoutes.mealHistory),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(80, 44),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  wide ? '饮食历史' : '全部记录',
                  style: const TextStyle(fontSize: 13),
                ),
                if (!wide) ...[
                  const SizedBox(width: 4),
                  Icon(AppIcons.chevronRight, size: 14),
                ],
              ],
            ),
          ),
        ],
      ),
      if (meals.isEmpty)
        const AppCard(child: Text('今天还没有餐食记录，可以拍照或手工记录。'))
      else if (wide)
        AppCard(
          radius: 16,
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 5),
          child: Column(
            children: [
              for (var i = 0; i < meals.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.only(left: 68),
                    child: Divider(height: 1),
                  ),
                _MealTile(meal: meals[i], wide: true),
              ],
            ],
          ),
        )
      else
        for (var i = 0; i < meals.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          AppCard(
            radius: 16,
            padding: EdgeInsets.zero,
            child: _MealTile(meal: meals[i]),
          ),
        ],
    ],
  );
}

class _MealTile extends StatelessWidget {
  const _MealTile({required this.meal, this.wide = false});
  final MealEntry meal;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final time =
        '${meal.consumedAt.hour.toString().padLeft(2, '0')}:${meal.consumedAt.minute.toString().padLeft(2, '0')}';
    final ready = meal.status == AnalysisStatus.ready;
    final amount = ready
        ? '${homeAmount(meal.nutrients.energy)} kcal'
        : meal.status == AnalysisStatus.failed
        ? '待补充'
        : '待分析';
    final status = AppBadge(
      label: !meal.confirmed ? '待确认' : meal.status.label,
      color: !meal.confirmed || !ready ? AppColors.amber : AppColors.green,
      compact: true,
    );
    final energy = Text(
      amount,
      style: TextStyle(
        fontSize: wide ? 16 : 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final source = Text(
      meal.source.label,
      style: TextStyle(
        color: AppColors.muted,
        fontSize: wide ? 12 : 11,
        height: 1.2,
      ),
    );
    final title = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 9,
      children: [
        Text(
          meal.type.label,
          style: TextStyle(
            fontSize: wide ? 16 : 15,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        Text(
          time,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: wide ? 13 : 12,
            height: 1.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
    final description = Text(
      meal.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.muted,
        fontSize: wide ? 14 : 13,
        height: 1.2,
      ),
    );
    return InkWell(
      onTap: () => context.push(AppRoutes.mealDetail(meal.id)),
      borderRadius: BorderRadius.circular(wide ? 12 : 16),
      child: Padding(
        padding: wide
            ? const EdgeInsets.symmetric(vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
            final stacked = largeText || (!wide && constraints.maxWidth < 320);
            return ConstrainedBox(
              constraints: BoxConstraints(minHeight: wide ? 54 : 63),
              child: Row(
                children: [
                  Semantics(
                    label: '餐盘示意，非实际照片',
                    image: true,
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const ExcludeSemantics(
                        child: PlateIllustration(size: 46),
                      ),
                    ),
                  ),
                  SizedBox(width: wide ? 16 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        const SizedBox(height: 5),
                        description,
                        if (!wide || stacked) ...[
                          const SizedBox(height: 4),
                          source,
                        ],
                        if (stacked) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [energy, status],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!stacked) ...[
                    const SizedBox(width: 8),
                    if (wide)
                      SizedBox(
                        width: 230,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Flexible(child: energy),
                                const SizedBox(width: 16),
                                status,
                              ],
                            ),
                            const SizedBox(height: 10),
                            source,
                          ],
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [energy, const SizedBox(height: 13), status],
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
