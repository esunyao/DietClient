import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// 同意记录 JSON 映射类型别名。
typedef ConsentJson = Map<String, dynamic>;

/// 当前登录用户真实同意历史列表 Provider；无 API 客户端或请求失败时不自动重试。
final consentRecordsProvider = FutureProvider<List<ConsentJson>>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (api == null) throw const ApiFailure('请先登录');
  return (await api.request('v1/users/self/consents') as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
}, retry: (count, error) => null);

/// 从同意记录中选出最新一条 AI 营养分析记录；按记录时间与精确整数 ID 降序排列。
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

/// 当前账户是否已授予政策版本 `1.0` 的有效 AI 营养分析同意。
final aiNutritionConsentProvider = FutureProvider<bool>((ref) async {
  final latest = latestAiConsent(
    await ref.watch(consentRecordsProvider.future),
  );
  return latest?['policyVersion'] == '1.0' && latest?['granted'] == true;
}, retry: (count, error) => null);

/// AI 营养分析授权管理器 Provider，统一刷新同意列表并在提交前强制向服务端重新核对。
final aiConsentManagerProvider = Provider<AiConsentManager>(
  AiConsentManager.new,
);

/// AI 授权状态管理器。
class AiConsentManager {
  AiConsentManager(this._ref);

  final Ref _ref;

  /// 失效同意记录缓存并触发重新拉取。
  void refreshRecords() => _ref.invalidate(consentRecordsProvider);

  /// 强制向服务端重新核对 AI 营养分析同意状态；未同意或读取失败时抛出 [ApiFailure]。
  Future<void> requireGranted() async {
    _ref.invalidate(consentRecordsProvider);
    if (!await _ref.read(aiNutritionConsentProvider.future)) {
      throw const ApiFailure('请先同意 AI 营养分析用途');
    }
  }
}

/// 强制向服务端重新核对 AI 营养分析同意状态（兼容入口，委托 [AiConsentManager]）。
Future<void> requireAiNutritionConsent(Ref ref) =>
    ref.read(aiConsentManagerProvider).requireGranted();
