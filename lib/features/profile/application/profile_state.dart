import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/privacy/ai_consent.dart';
import '../data/profile_api.dart';

/// @brief 资料接口客户端 Provider。
/// @details 随业务客户端装配资料 API；无客户端时不发起请求，销毁时关闭对象上传器。
final profileApiProvider = Provider<ProfileApi?>((ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  final api = ProfileApi(client);
  ref.onDispose(api.close);
  return api;
});

/// @brief 最近一次 PATCH 确认的档案快照 Provider。
/// @details 手动刷新时清除该快照以重新通过 GET 拉取服务端档案。
final confirmedProfileProvider = NotifierProvider<ConfirmedProfile, Json?>(
  ConfirmedProfile.new,
);

class ConfirmedProfile extends Notifier<Json?> {
  @override
  Json? build() {
    ref.watch(sessionEpochProvider);
    return null;
  }

  /// @brief 写入已确认的档案快照。
  /// @details 仅接受仍挂载且属于当前登录代次的保存结果，避免旧账户结果覆盖快照。
  /// @param value 服务端返回并已确认的档案 JSON。
  /// @param session 发起保存时的登录代次标识。
  /// @return 成功接受并更新状态时返回 true，否则返回 false。
  bool accept(Json value, Object? session) {
    if (!ref.mounted || ref.read(sessionEpochProvider) != session) {
      return false;
    }
    state = Map<String, dynamic>.unmodifiable(value);
    return true;
  }

  void clear() => state = null;
}

/// @brief 当前用户真实基础档案查询 Provider。
/// @details 优先使用保存确认的快照，否则读取真实档案；无客户端时返回空映射。
final profileProvider = FutureProvider<Json>((ref) async {
  ref.watch(sessionEpochProvider);
  final confirmed = ref.watch(confirmedProfileProvider);
  if (confirmed != null) return confirmed;
  return await ref.watch(profileApiProvider)?.profile() ?? {};
});

/// @brief 按健康类别独立查询真实健康记录列表的 Provider。
/// @details 无客户端时返回空列表，AI 同意记录复用共享状态。
final healthRecordsProvider = FutureProvider.family<List<Json>, String>(
  (ref, kind) async => await ref.watch(profileApiProvider)?.list(kind) ?? [],
);
final consentsProvider = consentRecordsProvider;
