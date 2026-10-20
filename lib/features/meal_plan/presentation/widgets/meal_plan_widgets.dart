import 'package:flutter/material.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/demo/demo_store.dart';

class PlanComparison extends StatelessWidget {
  const PlanComparison({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.wide,
  });

  final PlanOption selected;
  final ValueChanged<String> onSelected;
  final bool wide;

  Widget _name(PlanOption option) => Text(
    option.name,
    style: TextStyle(
      fontSize: wide ? 18 : 14,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: option.id == selected.id ? AppColors.primary : AppColors.ink,
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final gap = wide ? 20.0 : 8.0;
      final stacked =
          constraints.maxWidth < 340 ||
          MediaQuery.textScalerOf(context).scale(14) > 19;
      final width = stacked
          ? constraints.maxWidth
          : (constraints.maxWidth - gap * 2) / 3;
      return Wrap(
        spacing: gap,
        runSpacing: 12,
        children: [
          for (final option in demoPlans)
            SizedBox(
              width: width,
              child: Semantics(
                selected: option.id == selected.id,
                button: true,
                child: AppCard(
                  radius: 16,
                  padding: EdgeInsets.zero,
                  color: option.id == selected.id
                      ? AppColors.greenSoft
                      : AppColors.surface,
                  child: InkWell(
                    onTap: () => onSelected(option.id),
                    child: Container(
                      constraints: BoxConstraints(minHeight: wide ? 142 : 118),
                      padding: EdgeInsets.symmetric(
                        horizontal: wide ? 20 : 13,
                        vertical: wide ? 14 : 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: option.id == selected.id
                            ? Border.all(color: const Color(0xFFA8C6B1))
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _name(option)),
                                if (option.id == selected.id) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    AppIcons.checkCircle,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ],
                            )
                          else
                            _name(option),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                formatAmount(option.energy),
                                style: TextStyle(
                                  fontSize: wide ? 30 : 23,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              Text(
                                'kcal',
                                style: TextStyle(
                                  fontSize: wide ? 14 : 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          if (wide)
                            Wrap(
                              spacing: 14,
                              runSpacing: 4,
                              alignment: WrapAlignment.spaceBetween,
                              children: [
                                Text(
                                  '蛋白质 ${formatAmount(option.protein)} g',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.2,
                                    color: AppColors.muted,
                                  ),
                                ),
                                Text(
                                  '${option.minutes} 分钟',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.2,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            Text(
                              '蛋白质 ${formatAmount(option.protein)} g',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.2,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${option.minutes} 分钟',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.2,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                                if (option.id == selected.id)
                                  const Icon(
                                    AppIcons.checkCircle,
                                    size: 17,
                                    color: AppColors.primary,
                                  ),
                              ],
                            ),
                          ],
                          if (wide) ...[
                            const SizedBox(height: 4),
                            Text(
                              option.id == selected.id ? '已选择' : '查看方案',
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.2,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class PlanDishes extends StatelessWidget {
  const PlanDishes({super.key, required this.plan, required this.wide});

  final PlanOption plan;
  final bool wide;

  String _role(FoodPortion food) => switch (food.id) {
    'fish' || 'tofu' || 'chicken' => wide ? '主要蛋白质' : '优质蛋白',
    'rice' => '主食',
    'broccoli' || 'greens' => '蔬菜',
    _ => '方案菜品',
  };

  @override
  Widget build(BuildContext context) => AppCard(
    radius: wide ? 16 : 20,
    padding: EdgeInsets.symmetric(
      horizontal: wide ? 24 : 19,
      vertical: wide ? 12 : 6,
    ),
    child: Column(
      children: [
        for (var i = 0; i < plan.foods.length; i++) ...[
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: wide ? 70 : 66),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked =
                      constraints.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20;
                  final role = Text(
                    _role(plan.foods[i]),
                    style: TextStyle(
                      fontSize: wide ? 16 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: PlateIllustration(size: wide ? 40 : 36),
                      ),
                      SizedBox(width: wide ? 17 : 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.foods[i].name,
                              style: TextStyle(
                                fontSize: wide ? 16 : 15,
                                height: 1.3,
                                fontWeight: wide
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${formatAmount(plan.foods[i].grams)} g / 方案份量',
                              style: TextStyle(
                                fontSize: wide ? 13 : 12,
                                height: 1.3,
                                color: AppColors.muted,
                              ),
                            ),
                            if (stacked) ...[const SizedBox(height: 5), role],
                          ],
                        ),
                      ),
                      if (!stacked) ...[const SizedBox(width: 12), role],
                    ],
                  );
                },
              ),
            ),
          ),
          if (i < plan.foods.length - 1)
            Padding(
              padding: EdgeInsets.only(left: wide ? 65 : 58),
              child: const Divider(height: 1, color: AppColors.line),
            ),
        ],
      ],
    ),
  );
}

class PlanContextCard extends StatelessWidget {
  const PlanContextCard({
    super.key,
    required this.goal,
    required this.energy,
    required this.analyzing,
  });
  final String goal;
  final double? energy;
  final int analyzing;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(14) > 20) {
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '10月2日 / 晚餐',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  AppBadge(label: '演示方案'),
                ],
              );
            }
            return const Row(
              children: [
                Expanded(
                  child: Text(
                    '10月2日 / 晚餐',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                AppBadge(label: '演示方案'),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          '$goal；避开已登记的花生过敏原',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        Text(
          '今日已记录 ${formatAmount(energy)} kcal，仍有 $analyzing 餐分析中',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class PlanReasonCard extends StatelessWidget {
  const PlanReasonCard({
    super.key,
    required this.reason,
    required this.wide,
    required this.onHealthRecords,
  });
  final String reason;
  final bool wide;
  final VoidCallback onHealthRecords;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: wide ? 16 : 20,
    padding: EdgeInsets.all(wide ? 24 : 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(title: wide ? '搭配依据' : '为什么这样搭配'),
        const SizedBox(height: 16),
        Text(
          reason,
          style: const TextStyle(color: AppColors.muted, height: 1.7),
        ),
        const Divider(height: 32, color: AppColors.line),
        const Text(
          '先核对限制，再选餐',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        const Text(
          '花生过敏已登记。隐藏配料与交叉接触仍需核实，油盐用量也需确认。',
          style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.7),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: onHealthRecords, child: const Text('查看健康档案')),
      ],
    ),
  );
}

class PlanMenuCard extends StatelessWidget {
  const PlanMenuCard({super.key, required this.wide, required this.onMenu});
  final bool wide;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: wide ? 16 : 20,
    padding: EdgeInsets.all(wide ? 24 : 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(AppIcons.forkKnife, color: AppColors.primary, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '今天在食堂吃',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text('查看机构当天供应的菜单', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 8),
        const Text(
          '按菜品和份量选择，查看营养预览',
          style: TextStyle(fontSize: 14, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        AppButton(label: '打开食堂菜单', secondary: true, onPressed: onMenu),
      ],
    ),
  );
}
