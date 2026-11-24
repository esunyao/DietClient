import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/ui_preview_config.dart';
import '../../../../core/presentation/navigation_manager.dart';
import '../../../../core/presentation/unsupported_feature_page.dart';
import '../../../../demo/demo_store.dart';
import '../widgets/meal_plan_widgets.dart';

/// 配餐推荐页面，演示模式下支持方案切换与加入晚餐计划，原生模式显示暂未支持。
class MealPlanScreen extends ConsumerWidget {
  const MealPlanScreen({super.key});

  Future<void> _replacePlan(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: _buildReplacePlanSheet,
    );
    if (selected != null) {
      ref.read(demoProvider.notifier).selectPlan(selected);
    }
  }

  Widget _buildReplacePlanSheet(BuildContext sheetContext) => SafeArea(
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
                onTap: () => Navigator.pop(sheetContext, plan.id),
              ),
          ],
        ),
      ),
    ),
  );

  void _handleSavePlan(BuildContext context, WidgetRef ref) {
    ref.read(demoProvider.notifier).savePlan();
    showDemoMessage(context, '晚餐计划已在本次演示中更新，未增加实际摄入。');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(nativeNutritionEnabledProvider)) {
      return const UnsupportedFeaturePage(
        title: '下一餐怎么吃',
        description: '配餐方案与计划保存暂未支持。可以先记录实际餐食，查看真实营养汇总。',
        showBack: false,
      );
    }
    final state = ref.watch(demoProvider);
    final plan = state.selectedPlan;
    final analyzing = state.todayMeals
        .where((meal) => meal.status == AnalysisStatus.analyzing)
        .length;
    final navigation = ref.read(navigationManagerProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1024;
        final saveButton = AppButton(
          label: state.planSaved ? '已加入晚餐计划（演示）' : '加入晚餐计划',
          onPressed: state.planSaved
              ? null
              : () => _handleSavePlan(context, ref),
        );
        final nutrition = _PlanNutritionPreview(plan: plan, wide: wide);

        return AppPage(
          demoLabel: '设计样例 · 演示数据',
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
                      onTap: () => _replacePlan(context, ref),
                    ),
                    const SizedBox(height: 10),
                    PlanDishes(plan: plan, wide: wide),
                    const SizedBox(height: 16),
                    if (wide)
                      _WidePlanActionBar(
                        nutrition: nutrition,
                        saveButton: saveButton,
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: nutrition,
                      ),
                      const SizedBox(height: 16),
                      saveButton,
                    ],
                  ],
                ),
              ],
              aside: [
                PlanReasonCard(
                  reason: plan.reason,
                  wide: wide,
                  onHealthRecords: () => navigation.openHealthRecords(context),
                ),
                PlanMenuCard(
                  wide: wide,
                  onMenu: () => navigation.openInstitutionMenu(context),
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
                    onPressed: () => navigation.openInstitutionSync(context),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PlanNutritionPreview extends StatelessWidget {
  const _PlanNutritionPreview({required this.plan, required this.wide});

  final PlanOption plan;
  final bool wide;

  @override
  Widget build(BuildContext context) => Column(
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
}

class _WidePlanActionBar extends StatelessWidget {
  const _WidePlanActionBar({required this.nutrition, required this.saveButton});

  final Widget nutrition;
  final Widget saveButton;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 650 ||
          MediaQuery.textScalerOf(context).scale(14) > 20) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [nutrition, const SizedBox(height: 16), saveButton],
        );
      }
      return Row(
        children: [
          Expanded(child: nutrition),
          const SizedBox(width: 20),
          SizedBox(width: 238, child: saveButton),
        ],
      );
    },
  );
}
