import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/core/presentation/app_routes.dart';
import 'package:diet_client/demo/demo_store.dart';

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
    return AppPage(
      title: '下一餐怎么吃',
      subtitle: '为今天的晚餐选一个方案',
      children: [
        AdaptiveColumns(
          main: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '10月2日 / 晚餐',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text('${state.profile.goal}；避开已登记的花生过敏原'),
                  const SizedBox(height: 8),
                  Text(
                    '今日已记录 ${formatAmount(state.todayTotal.energy)} kcal，仍有 ${state.todayMeals.where((m) => m.status == AnalysisStatus.analyzing).length} 餐分析中',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SectionHeading(title: '比较三个方案'),
            LayoutBuilder(
              builder: (context, box) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final option in demoPlans)
                    SizedBox(
                      width: box.maxWidth < 370
                          ? box.maxWidth
                          : (box.maxWidth - 24) / 3,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => ref
                            .read(demoProvider.notifier)
                            .selectPlan(option.id),
                        child: AppCard(
                          color: option.id == plan.id
                              ? AppColors.greenSoft
                              : AppColors.surface,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                formatAmount(option.energy),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                'kcal',
                                style: TextStyle(color: AppColors.muted),
                              ),
                              const SizedBox(height: 8),
                              Text('蛋白质 ${formatAmount(option.protein)} g'),
                              Text('${option.minutes} 分钟'),
                              if (option.id == plan.id)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: AppBadge(label: '已选'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SectionHeading(
              title: plan.name,
              detail: '换一个菜',
              onTap: () => _replace(context, ref),
            ),
            AppCard(
              child: Column(
                children: [
                  for (final food in plan.foods)
                    AppListRow(
                      title: food.name,
                      subtitle: '${formatAmount(food.grams)} g / AI 估算示例',
                      leading: const PlateIllustration(size: 48),
                    ),
                ],
              ),
            ),
            AppCard(
              color: AppColors.greenSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('预计营养', style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    children: [
                      Text(
                        '${formatAmount(plan.energy)} kcal',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text('蛋白质 ${formatAmount(plan.protein)} g'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('方案仅供参考，加入计划不计入已摄入'),
                  const SizedBox(height: 16),
                  AppButton(
                    label: state.planSaved ? '已加入晚餐计划（演示）' : '加入晚餐计划',
                    onPressed: state.planSaved
                        ? null
                        : () {
                            ref.read(demoProvider.notifier).savePlan();
                            showDemoMessage(context, '晚餐计划已在本次演示中更新，未增加实际摄入。');
                          },
                  ),
                ],
              ),
            ),
          ],
          aside: [
            const SectionHeading(title: '为什么这样搭配'),
            AppCard(
              child: Text(
                '${plan.reason}\n\n使用已登记的过敏信息筛选；油盐用量仍需确认。\n\n当前记录未完整，不据此断定全天营养缺口。',
              ),
            ),
            const SectionHeading(title: '生成前，还可以调整'),
            AppCard(
              child: Column(
                children: [
                  AppListRow(
                    title: '时间与人数',
                    subtitle: '${plan.minutes} 分钟 / 1 人',
                    leading: const Icon(Icons.schedule),
                  ),
                  AppListRow(
                    title: '餐食来源',
                    subtitle: '自己做 / 食堂菜单演示',
                    leading: const Icon(Icons.restaurant_outlined),
                    onTap: () => context.push(AppRoutes.institutionMenu),
                  ),
                  AppListRow(
                    title: '健康资料与限制',
                    subtitle: '查看已登记信息与未知项目',
                    leading: const Icon(Icons.favorite_outline),
                    onTap: () => context.push(AppRoutes.healthRecords),
                  ),
                ],
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
  }
}
