import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/demo/demo_store.dart';
import 'package:diet_client/core/presentation/app_routes.dart';

import '../widgets/meal_widgets.dart';

class MealDetailScreen extends ConsumerWidget {
  const MealDetailScreen({super.key, required this.mealId});
  final String mealId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meal = ref.watch(demoProvider).meal(mealId);
    if (meal == null) {
      return const AppPage(
        title: '餐食详情',
        showBack: true,
        children: [InfoBanner(text: '这条记录不存在，可能已在演示中删除。')],
      );
    }
    final ready = meal.status == AnalysisStatus.ready;
    return AppPage(
      title: '${meal.type.label}营养',
      showBack: true,
      footer: AppButton(
        label: '核对并修正',
        onPressed: () => context.push(AppRoutes.mealCorrection(meal.id)),
      ),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    '${meal.consumedAt.month}月${meal.consumedAt.day}日 ${mealTime(meal.consumedAt)}',
                  ),
                  AppBadge(label: meal.status.label),
                ],
              ),
              const SizedBox(height: 20),
              const Center(child: PlateIllustration(size: 150)),
              const SizedBox(height: 12),
              Text(
                meal.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '餐盘示意 / ${meal.source.label}',
                style: const TextStyle(color: AppColors.muted),
              ),
              if (meal.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(meal.notes),
                ),
            ],
          ),
        ),
        if (!ready)
          InfoBanner(
            text: meal.status == AnalysisStatus.failed
                ? '分析失败。可手工补录本餐，当前没有可靠营养值。'
                : '分析中，可离开后查看。未分析的营养不按零计算。',
          ),
        if (!meal.confirmed) const InfoBanner(text: '本餐待确认，尚未计入已知摄入。'),
        SectionHeading(title: '本餐能量', detail: ready ? '当前整份营养' : '待分析'),
        MealNutrients(nutrients: ready ? meal.nutrients : const Nutrients()),
        const AppCard(
          child: AppListRow(title: '膳食评分', trailing: Text('暂未评估')),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeading(title: '其他营养素'),
              const SizedBox(height: 12),
              AppListRow(
                title: '钠',
                trailing: Text(
                  meal.nutrients.sodium == null
                      ? '暂无可靠数据'
                      : '${formatAmount(meal.nutrients.sodium)} mg',
                ),
              ),
              AppListRow(
                title: '膳食纤维',
                trailing: Text(
                  meal.nutrients.fiber == null
                      ? '暂无可靠数据'
                      : '${formatAmount(meal.nutrients.fiber)} g',
                ),
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeading(title: '识别出的菜品', detail: '核对份量'),
              if (meal.foods.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('暂无菜品明细，可在修正中补充。'),
                ),
              ...meal.foods.map(
                (food) => AppListRow(
                  title: food.name,
                  subtitle:
                      '${formatAmount(food.grams)} g / ${meal.source.label}',
                  trailing: Text(
                    food.nutrients.energy == null
                        ? '待补充'
                        : '${formatAmount(food.nutrients.energy)} kcal',
                  ),
                ),
              ),
            ],
          ),
        ),
        const InfoBanner(
          text: '请核对份量与烹饪方式\n照片难以确定全部油、盐、糖及隐藏配料。存在过敏或临床饮食限制时，请进一步核对。',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(title: '营养来源与覆盖'),
              const SizedBox(height: 12),
              Text(
                meal.source == RecordSource.photo
                    ? '菜品与份量来自图片估算；营养为演示样例值。'
                    : meal.source == RecordSource.manual
                    ? '本餐来自人工记录，已填营养由用户核对。'
                    : '本餐来自机构配方演示，需核对本人归属与实际食用量。',
              ),
              const SizedBox(height: 8),
              const Text('未知指标保持未知。人工修正不会被静默覆盖，重新分析前应保留修正。'),
            ],
          ),
        ),
      ],
    );
  }
}
