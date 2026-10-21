import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/demo/demo_store.dart';
import 'package:diet_client/core/presentation/app_routes.dart';

import '../widgets/meal_widgets.dart';
import '../../../../core/config/ui_preview_config.dart';
import 'native_meal_detail_screen.dart';

class MealDetailScreen extends ConsumerWidget {
  const MealDetailScreen({super.key, required this.mealId});
  final String mealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(nativeNutritionEnabledProvider)) {
      return NativeMealDetailScreen(mealId: mealId);
    }
    final meal = ref.watch(demoProvider).meal(mealId);
    if (meal == null) {
      return const AppPage(
        title: '餐食详情',
        showBack: true,
        children: [InfoBanner(text: '这条记录不存在，可能已在演示中删除。')],
      );
    }
    final ready = meal.status == AnalysisStatus.ready;
    void correct() => context.push(AppRoutes.mealCorrection(meal.id));
    final safeWidth =
        MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).horizontal;
    final pageWidth = safeWidth.clamp(0.0, AppLayout.maxPageWidth).toDouble();
    final wide =
        pageWidth - AppLayout.pageGutter(pageWidth) * 2 >=
        AppLayout.columnsMinWidth;
    return AppPage(
      title: '${meal.type.label}营养',
      showBack: true,
      footer: wide
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '结果为估算，可按实际食用量修正',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: '核对并修正',
                  icon: AppIcons.edit,
                  onPressed: correct,
                ),
              ],
            ),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= AppLayout.columnsMinWidth;
            final nutrients = MealNutrients(
              nutrients: ready ? meal.nutrients : const Nutrients(),
              expanded: columns,
            );
            return AdaptiveColumns(
              main: [
                AppCard(
                  radius: columns ? 16 : 20,
                  color: AppColors.greenSoft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${meal.consumedAt.month}月${meal.consumedAt.day}日 ${mealTime(meal.consumedAt)}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          AppBadge(
                            label: meal.status.label,
                            color: ready
                                ? AppColors.primary
                                : AppColors.amberInk,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          PlateIllustration(size: columns ? 130 : 104),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  meal.title,
                                  style: TextStyle(
                                    fontSize: columns ? 23 : 19,
                                    fontWeight: FontWeight.w700,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '餐盘示意 / ${meal.source.label}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (meal.notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            meal.notes,
                            style: const TextStyle(fontSize: 14),
                          ),
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
                if (!columns) nutrients,
                SectionHeading(
                  title: columns ? '本餐菜品' : '识别出的菜品',
                  detail: '核对份量',
                  onTap: correct,
                ),
                AppCard(
                  radius: columns ? 16 : 20,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      if (meal.foods.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('暂无菜品明细，可在修正中补充。'),
                        ),
                      for (var i = 0; i < meal.foods.length; i++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(3),
                                child: const PlateIllustration(size: 40),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      meal.foods[i].name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${formatAmount(meal.foods[i].grams)} g / ${meal.source.label}',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                meal.foods[i].nutrients.energy == null
                                    ? '待补充'
                                    : '${formatAmount(meal.foods[i].nutrients.energy)} kcal',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (i < meal.foods.length - 1)
                          const Divider(height: 1, indent: 60),
                      ],
                    ],
                  ),
                ),
                if (columns) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          '计量口径：熟重 / 估算实际食用量',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      AppButton(
                        label: '核对并修正',
                        secondary: true,
                        icon: AppIcons.edit,
                        onPressed: correct,
                      ),
                    ],
                  ),
                  const Text(
                    '人工修正不会被重新分析结果静默覆盖',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
                AppCard(
                  radius: columns ? 16 : 20,
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
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '未知指标保持未知。人工修正不会被静默覆盖，重新分析前应保留修正。',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
              aside: [
                if (columns) nutrients,
                const InfoBanner(
                  color: AppColors.amberInk,
                  icon: AppIcons.warning,
                  text: '核对份量与隐藏配料\n照片难以确定全部油、盐、糖及隐藏配料。存在过敏或临床饮食限制时，请进一步核对；出现冲突时交由专业人员审核。',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
