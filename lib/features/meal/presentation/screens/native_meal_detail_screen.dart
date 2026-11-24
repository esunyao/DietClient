import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/nutrition/application/analysis_polling.dart';
import '../../../../core/nutrition/application/nutrition_providers.dart';
import '../../../../core/presentation/app_routes.dart';
import '../../../../core/presentation/navigation_manager.dart';
import '../../../../core/session/session_controller.dart';
import '../widgets/meal_photo_widgets.dart';
import '../widgets/native_meal_widgets.dart';

/// 原生真实餐食详情页面，负责展示详情、触发重试分析、确认删除和跳转修正页。
class NativeMealDetailScreen extends ConsumerStatefulWidget {
  const NativeMealDetailScreen({super.key, required this.mealId});

  final String mealId;

  @override
  ConsumerState<NativeMealDetailScreen> createState() => _DetailState();
}

class _DetailState extends ConsumerState<NativeMealDetailScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _retry(Meal meal) async {
    if (_busy) return;
    final epoch = ref.read(sessionEpochProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(nutritionManagerProvider).retryMealAnalysis(meal);
    } catch (error) {
      if (mounted && ref.read(sessionEpochProvider) == epoch) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Meal meal) async {
    if (_busy) return;
    final epoch = ref.read(sessionEpochProvider);
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除这餐记录？',
      content: '删除后将更新当日及趋势统计，此操作无法撤销。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed || !mounted || ref.read(sessionEpochProvider) != epoch) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final deleted = await ref
          .read(nutritionManagerProvider)
          .deleteMeal(meal.mealId, epoch: epoch);
      if (!deleted || !mounted || ref.read(sessionEpochProvider) != epoch) {
        return;
      }
      if (ModalRoute.of(context)?.isCurrent != false) {
        ref
            .read(navigationManagerProvider)
            .returnOrFallback(context, AppRoutes.mealHistory);
      }
    } catch (error) {
      if (mounted && ref.read(sessionEpochProvider) == epoch) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(mealProvider(widget.mealId));
    final meal = result.value;
    final nutrition = ref.read(nutritionManagerProvider);
    final navigation = ref.read(navigationManagerProvider);

    return AppPage(
      demoLabel: null,
      title: '餐食详情',
      showBack: true,
      footer: meal == null
          ? null
          : AppButton(
              label: '核对并修正',
              icon: Icons.edit,
              onPressed: _busy
                  ? null
                  : () => navigation.openMealCorrection(context, meal.mealId),
            ),
      children: [
        if (result.isLoading && meal == null)
          const Center(child: CircularProgressIndicator()),
        if (result.hasError)
          NutritionError(
            error:
                result.error is ApiFailure &&
                    (result.error as ApiFailure).status == 404
                ? '这条记录不存在或已删除'
                : result.error!,
            retry: () => nutrition.refreshMeal(widget.mealId),
          ),
        if (_error != null) InfoBanner(text: _error!),
        // 待分析记录交给共享轮询组件；刷新期间保留已有记录继续展示。
        if (meal != null)
          NutritionPolling(
            refreshKey: widget.mealId,
            onRefresh: () => nutrition.refreshMealIfIdle(widget.mealId),
            pending: analysisPending(meal.analysisStatus),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MealHeaderCard(meal: meal),
                const SizedBox(height: 16),
                // 照片区域与营养分析状态解耦，由照片条内部独立处理加载与重试。
                MealPhotoStrip(mealId: meal.mealId),
                const SizedBox(height: 16),
                _MealNutrientSummaryCard(nutrients: meal.nutrients),
                const SizedBox(height: 16),
                const SectionHeading(title: '菜品与份量'),
                for (final item in meal.items) _MealItemCard(item: item),
                if (meal.analysisStatus == 'failed')
                  TextButton(
                    onPressed: _busy ? null : () => _retry(meal),
                    child: Text(_busy ? '正在重试…' : '重新分析（重新核验 AI 同意）'),
                  ),
                TextButton(
                  onPressed: _busy ? null : () => _delete(meal),
                  child: const Text(
                    '删除记录',
                    style: TextStyle(color: AppColors.red),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MealHeaderCard extends StatelessWidget {
  const _MealHeaderCard({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${meal.localDate} · ${mealTypeLabel(meal.mealType)}',
          style: AppTypography.pageTitle,
        ),
        Text('${meal.consumedAt.toLocal()} · ${meal.timezone}'),
        Text(analysisStatusLabel(meal.analysisStatus)),
        if (meal.notes != null) Text(meal.notes!),
      ],
    ),
  );
}

class _MealNutrientSummaryCard extends StatelessWidget {
  const _MealNutrientSummaryCard({required this.nutrients});

  final List<NutrientValue> nutrients;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(title: '本餐营养'),
        const SizedBox(height: 12),
        NativeNutrients(values: nutrients),
        const SizedBox(height: 12),
        const Text('缺少指标保持未知；照片估算需核对油、盐及隐藏配料。', style: AppTypography.small),
      ],
    ),
  );
}

class _MealItemCard extends StatelessWidget {
  const _MealItemCard({required this.item});

  final MealItem item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.displayName,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          Text(
            '${formatNutrientAmount(item.estimatedWeightG)} g · ${item.dataSource}'
            '${item.userCorrected ? ' · 已人工修正' : ''}',
          ),
          NativeNutrients(values: item.nutrients),
          if (item.notes != null) Text(item.notes!),
        ],
      ),
    ),
  );
}
