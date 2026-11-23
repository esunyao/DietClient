import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../network/api_client.dart';
import '../../config/ui_preview_config.dart';
import '../data/nutri_api.dart';
import '../data/nutri_models.dart';
export '../data/nutri_api.dart';
export '../data/nutri_models.dart';

// 使用设备时区插件的标识；查询失败时不自动重试。
final deviceTimezoneProvider = FutureProvider<String>(
  (ref) async => (await FlutterTimezone.getLocalTimezone()).identifier,
  retry: (count, error) => null,
);
// Web 和预览不创建真实营养 API；可用时依赖业务客户端，并随 Provider 释放上传器。
final nutritionApiProvider = Provider<NutriApi?>((ref) {
  if (kIsWeb || ref.watch(uiPreviewProvider)) return null;
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  final api = NutriApi(client);
  ref.onDispose(api.close);
  return api;
});
NutriApi _api(Ref ref) =>
    ref.watch(nutritionApiProvider) ?? (throw const ApiFailure('请先登录'));
// 共享策略、草稿和按参数分组的真实查询；这些 Provider 禁用自动重试。
final capturePolicyProvider = FutureProvider<CapturePolicy>(
  (ref) => _api(ref).capturePolicy(),
  retry: (count, error) => null,
);
final draftsProvider = FutureProvider<CaptureDraftPage>(
  (ref) => _api(ref).drafts(),
  retry: (count, error) => null,
);
final captureSessionProvider = FutureProvider.autoDispose
    .family<CaptureSession, String>(
      (ref, id) => _api(ref).captureSession(id),
      retry: (count, error) => null,
    );
final mealsProvider = FutureProvider.autoDispose.family<MealPage, MealQuery>(
  (ref, query) => _api(ref).meals(query),
  retry: (count, error) => null,
);
final mealProvider = FutureProvider.autoDispose.family<Meal, String>(
  (ref, id) => _api(ref).meal(id),
  retry: (count, error) => null,
);
final dailySummaryProvider = FutureProvider.autoDispose
    .family<DailySummary, String>(
      (ref, date) => _api(ref).dailySummary(date),
      retry: (count, error) => null,
    );
final dailyTrendProvider = FutureProvider.autoDispose
    .family<DailyTrend, TrendQuery>(
      (ref, query) => _api(ref).dailyTrend(query),
      retry: (count, error) => null,
    );

/// Call after successful create/submit/retry/correction/delete; invalidates all query keys.
void invalidateNutrition(Ref ref) {
  ref.invalidate(draftsProvider);
  ref.invalidate(captureSessionProvider);
  ref.invalidate(mealsProvider);
  ref.invalidate(mealProvider);
  ref.invalidate(dailySummaryProvider);
  ref.invalidate(dailyTrendProvider);
}

/// 供组件侧集中失效营养查询；与 Ref 入口覆盖相同的查询族。
void refreshNutrition(WidgetRef ref) {
  ref.invalidate(draftsProvider);
  ref.invalidate(captureSessionProvider);
  ref.invalidate(mealsProvider);
  ref.invalidate(mealProvider);
  ref.invalidate(dailySummaryProvider);
  ref.invalidate(dailyTrendProvider);
}
