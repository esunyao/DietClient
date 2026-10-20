import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/core/presentation/app_routes.dart';
import 'package:diet_client/demo/demo_store.dart';

import '../widgets/meal_plan_widgets.dart';

class MealPlanScreen extends ConsumerWidget {
  const MealPlanScreen({super.key});

  Future<void> _replace(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '换一个菜',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text('选择另一个完整套餐示例，预计营养与制作时间一并更新；单菜替换需核对配方。'),
                for (final plan in demoPlans)
                  ListTile(
                    title: Text(plan.name),
                    subtitle: Text(
                      '${formatAmount(plan.energy)} kcal · 蛋白质 ${formatAmount(plan.protein)} g',
                    ),
                    onTap: () => Navigator.pop(context, plan.id),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null) ref.read(demoProvider.notifier).selectPlan(selected);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoProvider);
    final plan = state.selectedPlan;
    final analyzing = state.todayMeals
        .where((meal) => meal.status == AnalysisStatus.analyzing)
        .length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1024;
        final save = AppButton(
          label: state.planSaved ? '已加入晚餐计划（演示）' : '加入晚餐计划',
          onPressed: state.planSaved
              ? null
              : () {
                  ref.read(demoProvider.notifier).savePlan();
                  showDemoMessage(context, '晚餐计划已在本次演示中更新，未增加实际摄入。');
                },
        );
        final nutrition = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!wide)
              const Text(
                '预计营养',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            Wrap(
              spacing: wide ? 8 : 24,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${wide ? '预计营养 ' : ''}${formatAmount(plan.energy)} kcal',
                  style: TextStyle(
                    fontSize: wide ? 16 : 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${wide ? '· ' : ''}蛋白质 ${formatAmount(plan.protein)} g',
                  style: TextStyle(
                    fontSize: 14,
                    color: wide ? AppColors.ink : AppColors.muted,
                    fontWeight: wide ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '方案仅供参考，加入计划不计入已摄入',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        );
        return AppPage(
          title: wide ? '下一餐，选一个合适的搭配' : '下一餐怎么吃',
          eyebrow: wide ? null : '为今天的晚餐选一个方案',
          subtitle: wide
              ? '10月2日晚餐 · ${state.profile.goal} · 参考已登记的花生过敏信息'
              : null,
          children: [
            AdaptiveColumns(
              main: [
                if (!wide)
                  PlanContextCard(
                    goal: state.profile.goal,
                    energy: state.todayTotal.energy,
                    analyzing: analyzing,
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeading(title: wide ? '三个可选方案' : '比较三个方案'),
                    const SizedBox(height: 14),
                    PlanComparison(
                      selected: plan,
                      wide: wide,
                      onSelected: (id) =>
                          ref.read(demoProvider.notifier).selectPlan(id),
                    ),
                    const SizedBox(height: 20),
                    SectionHeading(
                      title: plan.name,
                      detail: wide ? '替换菜品' : '换一个菜',
                      onTap: () => _replace(context, ref),
                    ),
                    const SizedBox(height: 10),
                    PlanDishes(plan: plan, wide: wide),
                    const SizedBox(height: 16),
                    if (wide)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 650 ||
                              MediaQuery.textScalerOf(context).scale(14) > 20) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                nutrition,
                                const SizedBox(height: 16),
                                save,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: nutrition),
                              const SizedBox(width: 20),
                              SizedBox(width: 238, child: save),
                            ],
                          );
                        },
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: nutrition,
                      ),
                      const SizedBox(height: 16),
                      save,
                    ],
                  ],
                ),
              ],
              aside: [
                PlanReasonCard(
                  reason: plan.reason,
                  wide: wide,
                  onHealthRecords: () => context.push(AppRoutes.healthRecords),
                ),
                PlanMenuCard(
                  wide: wide,
                  onMenu: () => context.push(AppRoutes.institutionMenu),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '${plan.minutes} 分钟 / 1 人 · 方案份量\n今日已记录 ${formatAmount(state.todayTotal.energy)} kcal\n当前记录尚未完整，不据此确定全天营养缺口。',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                      height: 1.8,
                    ),
                  ),
                ),
                if (state.isInstitution)
                  AppButton(
                    label: '查看机构餐食同步',
                    secondary: true,
                    onPressed: () => context.push(AppRoutes.institutionSync),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
