import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';

import '../../../../core/presentation/app_routes.dart';
import '../../../../core/presentation/unsaved_form.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/privacy/ai_consent.dart';
import '../../../../core/nutrition/application/nutrition_providers.dart';
import '../../../../core/nutrition/application/analysis_polling.dart';
import '../widgets/native_meal_widgets.dart';
import '../widgets/meal_photo_widgets.dart';

final _retryMealProvider = Provider<Future<void> Function(Meal)>(
  (ref) => (meal) async {
    final epoch = ref.read(sessionEpochProvider);
    final api = ref.read(nutritionApiProvider);
    if (api == null) throw const ApiFailure('请先登录');
    await requireAiNutritionConsent(ref);
    if (ref.read(sessionEpochProvider) != epoch) {
      throw const ApiFailure('会话已更换');
    }
    await api.retry(meal.captureSessionId);
    if (ref.read(sessionEpochProvider) == epoch) invalidateNutrition(ref);
  },
);

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
      await ref.read(_retryMealProvider)(meal);
    } catch (e) {
      if (mounted && ref.read(sessionEpochProvider) == epoch) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Meal meal) async {
    if (_busy) return;
    final epoch = ref.read(sessionEpochProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这餐记录？'),
        content: const Text('删除后将更新当日及趋势统计，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        ref.read(sessionEpochProvider) != epoch) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(nutritionApiProvider);
      if (api == null) throw const ApiFailure('请先登录');
      await api.deleteMeal(meal.mealId);
      if (!mounted || ref.read(sessionEpochProvider) != epoch) return;
      refreshNutrition(ref);
      if (ModalRoute.of(context)?.isCurrent != false) {
        returnOrGo(context, AppRoutes.mealHistory);
      }
    } catch (e) {
      if (mounted && ref.read(sessionEpochProvider) == epoch) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(mealProvider(widget.mealId));
    final meal = result.value;
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
                  : () => context.push(AppRoutes.mealCorrection(meal.mealId)),
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
            retry: () => ref.invalidate(mealProvider(widget.mealId)),
          ),
        if (_error != null) InfoBanner(text: _error!),
        if (meal != null)
          NutritionPolling(
            refreshKey: widget.mealId,
            onRefresh: () {
              if (!ref.read(mealProvider(widget.mealId)).isLoading) {
                ref.invalidate(mealProvider(widget.mealId));
              }
            },
            pending: analysisPending(meal.analysisStatus),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${meal.localDate} · ${mealTypes[meal.mealType] ?? meal.mealType}',
                        style: AppTypography.pageTitle,
                      ),
                      Text('${meal.consumedAt.toLocal()} · ${meal.timezone}'),
                      Text(statusLabel(meal.analysisStatus)),
                      if (meal.notes != null) Text(meal.notes!),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                MealPhotoStrip(mealId: meal.mealId),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeading(title: '本餐营养'),
                      const SizedBox(height: 12),
                      NativeNutrients(values: meal.nutrients),
                      const SizedBox(height: 12),
                      const Text(
                        '缺少指标保持未知；照片估算需核对油、盐及隐藏配料。',
                        style: AppTypography.small,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionHeading(title: '菜品与份量'),
                for (final item in meal.items)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.displayName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${amountText(item.estimatedWeightG)} g · ${item.dataSource}${item.userCorrected ? ' · 已人工修正' : ''}',
                          ),
                          NativeNutrients(values: item.nutrients),
                          if (item.notes != null) Text(item.notes!),
                        ],
                      ),
                    ),
                  ),
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
