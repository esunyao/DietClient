import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/privacy/ai_consent.dart';
import '../data/profile_api.dart';

/// 随业务客户端装配资料 API；无客户端时不发起请求，销毁时关闭上传器。
final profileApiProvider = Provider<ProfileApi?>((ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  final api = ProfileApi(client);
  ref.onDispose(api.close);
  return api;
});

/// PATCH 返回值是当前已确认档案，手动刷新时清除后重新 GET。
final confirmedProfileProvider = NotifierProvider<ConfirmedProfile, Json?>(
  ConfirmedProfile.new,
);

class ConfirmedProfile extends Notifier<Json?> {
  @override
  Json? build() {
    ref.watch(sessionEpochProvider);
    return null;
  }

  /// 仅接受仍挂载且属于当前登录代次的保存结果，避免旧账户结果覆盖快照。
  bool accept(Json value, Object? session) {
    if (!ref.mounted || ref.read(sessionEpochProvider) != session) {
      return false;
    }
    state = Map<String, dynamic>.unmodifiable(value);
    return true;
  }

  void clear() => state = null;
}

/// 优先使用保存确认的快照，否则读取真实档案；无客户端时返回空映射。
final profileProvider = FutureProvider<Json>((ref) async {
  ref.watch(sessionEpochProvider);
  final confirmed = ref.watch(confirmedProfileProvider);
  if (confirmed != null) return confirmed;
  return await ref.watch(profileApiProvider)?.profile() ?? {};
});
/// 按类别独立查询健康记录；无客户端时返回空列表，同意记录复用共享状态。
final healthRecordsProvider = FutureProvider.family<List<Json>, String>(
  (ref, kind) async => await ref.watch(profileApiProvider)?.list(kind) ?? [],
);
final consentsProvider = consentRecordsProvider;
