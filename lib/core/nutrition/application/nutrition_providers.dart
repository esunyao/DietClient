import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../network/api_client.dart';
import '../../config/ui_preview_config.dart';
import '../data/nutri_api.dart';
import '../data/nutri_models.dart';
export '../data/nutri_api.dart';
export '../data/nutri_models.dart';

final deviceTimezoneProvider = FutureProvider<String>(
  (ref) async => (await FlutterTimezone.getLocalTimezone()).identifier,
  retry: (count, error) => null,
);
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

void refreshNutrition(WidgetRef ref) {
  ref.invalidate(draftsProvider);
  ref.invalidate(captureSessionProvider);
  ref.invalidate(mealsProvider);
  ref.invalidate(mealProvider);
  ref.invalidate(dailySummaryProvider);
  ref.invalidate(dailyTrendProvider);
}
