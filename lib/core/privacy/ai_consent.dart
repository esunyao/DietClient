import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

typedef ConsentJson = Map<String, dynamic>;
final consentRecordsProvider = FutureProvider<List<ConsentJson>>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (api == null) throw const ApiFailure('请先登录');
  return (await api.request('v1/users/self/consents') as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
}, retry: (count, error) => null);
ConsentJson? latestAiConsent(List<ConsentJson> records) {
  final items = records
      .where((item) => item['consentType'] == 'ai_nutrition_analysis')
      .toList();
  items.sort((a, b) {
    final time = DateTime.parse(b['recordedAt'] as String)
        .compareTo(DateTime.parse(a['recordedAt'] as String));
    return time != 0
        ? time
        : BigInt.parse('${b['consentId']}')
              .compareTo(BigInt.parse('${a['consentId']}'));
  });
  return items.isEmpty ? null : items.first;
}

final aiNutritionConsentProvider = FutureProvider<bool>((ref) async {
  final latest = latestAiConsent(
    await ref.watch(consentRecordsProvider.future),
  );
  return latest?['policyVersion'] == '1.0' && latest?['granted'] == true;
}, retry: (count, error) => null);
Future<void> requireAiNutritionConsent(Ref ref) async {
  // A submission must recheck the server, even if a page previously displayed consent.
  ref.invalidate(consentRecordsProvider);
  if (!await ref.read(aiNutritionConsentProvider.future)) {
    throw const ApiFailure('请先同意 AI 营养分析用途');
  }
}
