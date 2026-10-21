import 'package:diet_models/diet_models.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/nutrition/application/nutrition_providers.dart';
import '../../../../core/nutrition/application/analysis_polling.dart';
import '../../../../core/presentation/account_identity.dart';
import '../widgets/personal_home_content.dart';
import '../widgets/home_summary.dart';

String _date(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class NativeHomeScreen extends ConsumerWidget {
  const NativeHomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = _date(DateTime.now());
    final query = (
      dateFrom: today,
      dateTo: today,
      mealType: null,
      keyword: null,
      page: 1,
      pageSize: 100,
    );
    final summary = ref.watch(dailySummaryProvider(today));
    final meals = ref.watch(mealsProvider(query));
    final entries = meals.value?.items ?? [];
    final nutrients = summary.value?.nutrients ?? [];
    return AppPage(
      demoLabel: null,
      title: '今天，好好吃饭',
      titleStyle: AppTypography.pageTitle.copyWith(fontSize: 24),
      mobileGutter: 20,
      eyebrow:
          '${DateTime.now().month}月${DateTime.now().day}日，星期${'一二三四五六日'[DateTime.now().weekday - 1]}',
      trailing: const AccountAvatar(size: 48),
      children: [
        NutritionPolling(
          refreshKey: query,
          onRefresh: () {
            ref.invalidate(mealsProvider(query));
            ref.invalidate(dailySummaryProvider(today));
          },
          pending: entries.any((m) => analysisPending(m.analysisStatus)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HomeRecordEntry(),
              const SizedBox(height: 20),
              const HomeQuickActions(),
              const SizedBox(height: 20),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '今日营养',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text('营养目标：未设置', style: AppTypography.small),
                    if (summary.isLoading && summary.value == null)
                      const LinearProgressIndicator(),
                    if (summary.hasError)
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(dailySummaryProvider(today)),
                        child: const Text('今日营养加载失败，点击重试'),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      '${homeAmount(nutrientAmount(nutrients, 'ENERGY_KCAL'))} kcal',
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 24,
                      runSpacing: 10,
                      children: [
                        for (final field in const [
                          ('PROTEIN', '蛋白质'),
                          ('CARBOHYDRATE', '碳水化合物'),
                          ('FAT', '脂肪'),
                        ])
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(field.$2),
                              Text(
                                '${homeAmount(nutrientAmount(nutrients, field.$1))} g',
                                style: AppTypography.caption,
                              ),
                              const Text('目标未设置', style: AppTypography.small),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '仅统计已有记录，不代表完整全天摄入。缺少指标保持未知。',
                      style: AppTypography.small,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (meals.isLoading && meals.value == null)
                const Center(child: CircularProgressIndicator()),
              if (meals.hasError)
                TextButton(
                  onPressed: () => ref.invalidate(mealsProvider(query)),
                  child: const Text('今日餐食加载失败，点击重试'),
                ),
              if (meals.value != null)
                HomeMeals(
                  sourceLabel: '拍照记录',
                  statusLabels: {
                    for (final meal in entries)
                      meal.mealId: switch (meal.analysisStatus) {
                        'queued' || 'pending' => '待分析',
                        'analysing' || 'analyzing' => '分析中',
                        'completed' => '已分析',
                        'failed' => '分析失败',
                        'needs_review' => '需要核对',
                        _ => meal.analysisStatus,
                      },
                  },
                  meals: [
                    for (final meal in entries)
                      MealEntry(
                        id: meal.mealId,
                        title: meal.notes?.isNotEmpty == true
                            ? meal.notes!
                            : '餐食记录',
                        type: MealType.values.firstWhere(
                          (t) => t.name == meal.mealType,
                          orElse: () => MealType.other,
                        ),
                        consumedAt: meal.consumedAt.toLocal(),
                        nutrients: Nutrients(
                          energy: nutrientAmount(meal.nutrients, 'ENERGY_KCAL'),
                          protein: nutrientAmount(meal.nutrients, 'PROTEIN'),
                          carbs: nutrientAmount(meal.nutrients, 'CARBOHYDRATE'),
                          fat: nutrientAmount(meal.nutrients, 'FAT'),
                        ),
                        status: analysisPending(meal.analysisStatus)
                            ? AnalysisStatus.analyzing
                            : meal.analysisStatus == 'completed'
                            ? AnalysisStatus.ready
                            : AnalysisStatus.failed,
                      ),
                  ],
                ),
              if ((meals.value?.total ?? 0) > entries.length)
                const Text('今日记录较多，可在历史查看全部记录。', style: AppTypography.small),
            ],
          ),
        ),
      ],
    );
  }
}
