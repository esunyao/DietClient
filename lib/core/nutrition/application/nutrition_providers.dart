import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../config/ui_preview_config.dart';
import '../../network/api_client.dart';
import '../data/nutri_api.dart';
import '../data/nutri_models.dart';
import 'nutrition_manager.dart';

export '../data/nutri_api.dart';
export '../data/nutri_models.dart';
export '../data/nutrition_format.dart';
export 'nutrition_manager.dart';

/// 设备本地时区标识 Provider；查询失败时不自动重试。
final deviceTimezoneProvider = FutureProvider<String>(
  (ref) async => (await FlutterTimezone.getLocalTimezone()).identifier,
  retry: (count, error) => null,
);

/// 真实营养业务 API 客户端 Provider；Web 与预览环境返回 `null`，销毁时关闭上传器。
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

/// 采集策略查询 Provider（禁用自动重试）。
final capturePolicyProvider = FutureProvider<CapturePolicy>(
  (ref) => _api(ref).capturePolicy(),
  retry: (count, error) => null,
);

/// 采集草稿列表查询 Provider（禁用自动重试）。
final draftsProvider = FutureProvider<CaptureDraftPage>(
  (ref) => _api(ref).drafts(),
  retry: (count, error) => null,
);

/// 按会话 ID 查询采集草稿详情 Provider。
final captureSessionProvider = FutureProvider.autoDispose
    .family<CaptureSession, String>(
      (ref, id) => _api(ref).captureSession(id),
      retry: (count, error) => null,
    );

/// 按筛选参数查询分页餐食历史 Provider。
final mealsProvider = FutureProvider.autoDispose.family<MealPage, MealQuery>(
  (ref, query) => _api(ref).meals(query),
  retry: (count, error) => null,
);

/// 按餐食 ID 查询单餐详情 Provider。
final mealProvider = FutureProvider.autoDispose.family<Meal, String>(
  (ref, id) => _api(ref).meal(id),
  retry: (count, error) => null,
);

/// 按本地日期（`YYYY-MM-DD`）查询当日营养汇总 Provider。
final dailySummaryProvider = FutureProvider.autoDispose
    .family<DailySummary, String>(
      (ref, date) => _api(ref).dailySummary(date),
      retry: (count, error) => null,
    );

/// 按起止日期查询每日营养趋势 Provider。
final dailyTrendProvider = FutureProvider.autoDispose
    .family<DailyTrend, TrendQuery>(
      (ref, query) => _api(ref).dailyTrend(query),
      retry: (count, error) => null,
    );

/// 通过 [Ref] 失效所有共享营养查询（写入成功后的兼容入口，内部委托 [NutritionManager]）。
void invalidateNutrition(Ref ref) =>
    ref.read(nutritionManagerProvider).refreshAll();

/// 通过 [WidgetRef] 失效所有共享营养查询（兼容入口，内部委托 [NutritionManager]）。
void refreshNutrition(WidgetRef ref) =>
    ref.read(nutritionManagerProvider).refreshAll();
