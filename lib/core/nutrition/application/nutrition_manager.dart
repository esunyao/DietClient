import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../network/api_client.dart';
import '../../privacy/ai_consent.dart';
import '../../session/session_controller.dart';
import 'meal_photo_providers.dart';
import 'nutrition_providers.dart';

/// 真实营养业务统一管理器 Provider，集中协调查询刷新与餐食写操作。
final nutritionManagerProvider = Provider<NutritionManager>(
  NutritionManager.new,
);

/// 真实营养业务管理器，封装查询失效、轮询空闲刷新及重试/修正/删除餐食操作。
class NutritionManager {
  NutritionManager(this._ref);

  final Ref _ref;

  NutriApi _requireApi() =>
      _ref.read(nutritionApiProvider) ?? (throw const ApiFailure('请先登录'));

  void _checkEpoch(int epoch) {
    if (_ref.read(sessionEpochProvider) != epoch) {
      throw const ApiFailure('会话已更换');
    }
  }

  /// 失效所有共享营养与餐食查询，触发重新拉取。
  void refreshAll() {
    _ref.invalidate(draftsProvider);
    _ref.invalidate(captureSessionProvider);
    _ref.invalidate(mealsProvider);
    _ref.invalidate(mealProvider);
    _ref.invalidate(dailySummaryProvider);
    _ref.invalidate(dailyTrendProvider);
  }

  /// 失效单餐详情查询。
  void refreshMeal(String id) => _ref.invalidate(mealProvider(id));

  /// 若单餐详情当前未在加载，则失效查询以供轮询刷新。
  void refreshMealIfIdle(String id) {
    if (!_ref.read(mealProvider(id)).isLoading) {
      _ref.invalidate(mealProvider(id));
    }
  }

  /// 失效指定筛选条件的餐食列表查询。
  void refreshMeals(MealQuery query) => _ref.invalidate(mealsProvider(query));

  /// 若指定餐食列表查询当前未在加载，则失效查询以供轮询刷新。
  void refreshMealsIfIdle(MealQuery query) {
    if (!_ref.read(mealsProvider(query)).isLoading) {
      _ref.invalidate(mealsProvider(query));
    }
  }

  /// 失效指定日期的每日营养汇总查询。
  void refreshDailySummary(String date) =>
      _ref.invalidate(dailySummaryProvider(date));

  /// 若指定日期汇总未在加载，则失效查询以供轮询刷新。
  void refreshDailySummaryIfIdle(String date) {
    if (!_ref.read(dailySummaryProvider(date)).isLoading) {
      _ref.invalidate(dailySummaryProvider(date));
    }
  }

  /// 失效指定日期范围的每日营养趋势查询。
  void refreshDailyTrend(TrendQuery query) =>
      _ref.invalidate(dailyTrendProvider(query));

  /// 失效采集策略查询。
  void refreshPolicy() => _ref.invalidate(capturePolicyProvider);

  /// 失效采集草稿列表查询。
  void refreshDrafts() => _ref.invalidate(draftsProvider);

  /// 失效指定餐食的照片元数据查询。
  void refreshPhotos(String mealId) =>
      _ref.invalidate(mealPhotosProvider(mealId));

  /// 失效指定图片的字节缓存查询。
  void refreshPhotoBytes(MealPhotoKey key) =>
      _ref.invalidate(mealPhotoBytesProvider(key));

  /// 重新发起失败餐食的 AI 分析：先核验 AI 同意，再校验登录代次并刷新共享查询。
  Future<void> retryMealAnalysis(Meal meal) async {
    final epoch = _ref.read(sessionEpochProvider);
    final api = _requireApi();
    await _ref.read(aiConsentManagerProvider).requireGranted();
    _checkEpoch(epoch);
    await api.retry(meal.captureSessionId);
    if (_ref.read(sessionEpochProvider) == epoch) {
      refreshAll();
    }
  }

  /// 删除指定餐食记录，并在仍属于 [epoch] 时刷新共享营养查询。
  Future<bool> deleteMeal(String mealId, {required int epoch}) async {
    final api = _requireApi();
    await api.deleteMeal(mealId);
    if (!_ref.mounted || _ref.read(sessionEpochProvider) != epoch) {
      return false;
    }
    refreshAll();
    return true;
  }

  /// 保存餐食修正：菜品列表有变化时整表替换，否则仅局部更新餐次元数据。
  Future<Meal?> saveMealCorrection({
    required Meal original,
    required String mealType,
    required DateTime consumedAt,
    required String notes,
    required bool itemsChanged,
    required List<MealCorrectionItem> items,
    required int epoch,
  }) async {
    final api = _requireApi();
    final Meal saved;
    if (itemsChanged) {
      if (items.length > 100) {
        throw const FormatException('最多 100 道菜');
      }
      saved = await api.replaceItems(
        original.mealId,
        MealCorrection(
          mealType: mealType,
          consumedAt: consumedAt,
          timezone: original.timezone,
          notes: notes,
          items: items,
        ),
      );
    } else {
      saved = await api.patchMeal(
        original.mealId,
        mealType: mealType,
        consumedAt: consumedAt,
        timezone: original.timezone,
        notes: notes,
      );
    }
    if (!_ref.mounted || _ref.read(sessionEpochProvider) != epoch) {
      return null;
    }
    refreshAll();
    _ref.read(mealProvider(saved.mealId));
    return saved;
  }
}
