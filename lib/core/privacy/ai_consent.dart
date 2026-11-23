import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

typedef ConsentJson = Map<String, dynamic>;
/// 读取当前登录用户的真实同意历史；无 API 客户端或请求失败时不自动重试。
final consentRecordsProvider = FutureProvider<List<ConsentJson>>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (api == null) throw const ApiFailure('请先登录');
  return (await api.request('v1/users/self/consents') as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
}, retry: (count, error) => null);
/// 只选择 AI 营养分析记录，按记录时间降序、同时间按精确整数 ID 降序取最新项。
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

/// 最新记录必须同时为政策版本 1.0 和已授权；查询错误继续向调用方传播。
final aiNutritionConsentProvider = FutureProvider<bool>((ref) async {
  final latest = latestAiConsent(
    await ref.watch(consentRecordsProvider.future),
  );
  return latest?['policyVersion'] == '1.0' && latest?['granted'] == true;
}, retry: (count, error) => null);
/// 提交或重试前使历史查询失效并重新核对；未授权或读取失败均不通过。
Future<void> requireAiNutritionConsent(Ref ref) async {
  // A submission must recheck the server, even if a page previously displayed consent.
  ref.invalidate(consentRecordsProvider);
  if (!await ref.read(aiNutritionConsentProvider.future)) {
    throw const ApiFailure('请先同意 AI 营养分析用途');
  }
}
