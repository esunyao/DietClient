import 'package:diet_models/diet_models.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/nutrition/application/analysis_polling.dart';
import '../../../../core/nutrition/application/nutrition_providers.dart';
import '../../../../core/presentation/account_identity.dart';
import '../../../../core/presentation/current_date.dart';
import '../widgets/home_summary.dart';
import '../widgets/personal_home_content.dart';

/// 真实营养首页，按本地当前日期查询当日汇总与餐食记录。
class NativeHomeScreen extends ConsumerWidget {
  const NativeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(currentDateProvider);
    final today = formatIsoDate(date);
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
    final nutrition = ref.read(nutritionManagerProvider);
    final entries = meals.value?.items ?? const <MealHistoryItem>[];
    final nutrients = summary.value?.nutrients ?? const <NutrientValue>[];

    return AppPage(
      demoLabel: null,
      title: '今天，好好吃饭',
      titleStyle: AppTypography.pageTitle.copyWith(fontSize: 24),
      mobileGutter: 20,
      eyebrow: '${date.month}月${date.day}日，星期${'一二三四五六日'[date.weekday - 1]}',
      trailing: const AccountAvatar(size: 48),
      children: [
        // 存在待分析记录时驱动轮询，空闲状态下仅失效对应查询。
        NutritionPolling(
          refreshKey: query,
          onRefresh: () {
            nutrition.refreshMealsIfIdle(query);
            nutrition.refreshDailySummaryIfIdle(today);
          },
          pending: entries.any((m) => analysisPending(m.analysisStatus)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HomeRecordEntry(),
              const SizedBox(height: 20),
              const HomeQuickActions(),
              const SizedBox(height: 20),
              _NativeDailySummaryCard(
                summary: summary,
                nutrients: nutrients,
                onRetry: () => nutrition.refreshDailySummary(today),
              ),
              const SizedBox(height: 12),
              if (meals.isLoading && meals.value == null)
                const Center(child: CircularProgressIndicator()),
              if (meals.hasError)
                TextButton(
                  onPressed: () => nutrition.refreshMeals(query),
                  child: const Text('今日餐食加载失败，点击重试'),
                ),
              if (meals.value != null)
                HomeMeals(
                  sourceLabel: '拍照记录',
                  statusLabels: {
                    for (final meal in entries)
                      meal.mealId: analysisStatusLabel(
                        meal.analysisStatus,
                        queuedLabel: '待分析',
                      ),
                  },
                  meals: _adaptMealEntries(entries),
                ),
              if ((meals.value?.total ?? 0) > entries.length)
                const Text('今日记录较多，可在历史查看全部记录。', style: AppTypography.small),
            ],
          ),
        ),
      ],
    );
  }

  static List<MealEntry> _adaptMealEntries(List<MealHistoryItem> entries) => [
    for (final meal in entries)
      MealEntry(
        id: meal.mealId,
        title: meal.notes?.isNotEmpty == true ? meal.notes! : '餐食记录',
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
  ];
}

class _NativeDailySummaryCard extends StatelessWidget {
  const _NativeDailySummaryCard({
    required this.summary,
    required this.nutrients,
    required this.onRetry,
  });

  final AsyncValue<DailySummary> summary;
  final List<NutrientValue> nutrients;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '今日营养',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const Text('营养目标：未设置', style: AppTypography.small),
        if (summary.isLoading && summary.value == null)
          const LinearProgressIndicator(),
        if (summary.hasError)
          TextButton(onPressed: onRetry, child: const Text('今日营养加载失败，点击重试')),
        const SizedBox(height: 10),
        Text(
          '${homeAmount(nutrientAmount(nutrients, 'ENERGY_KCAL'))} kcal',
          style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
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
        const Text('仅统计已有记录，不代表完整全天摄入。缺少指标保持未知。', style: AppTypography.small),
      ],
    ),
  );
}
