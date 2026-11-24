import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/privacy/ai_consent.dart';
import '../../../core/session/session_controller.dart';
import '../data/profile_api.dart';

export 'profile_manager.dart';

/// 资料接口客户端 Provider；随业务客户端装配，销毁时释放上传器。
final profileApiProvider = Provider<ProfileApi?>((ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  final api = ProfileApi(client);
  ref.onDispose(api.close);
  return api;
});

/// 最近一次 PATCH 确认的档案快照 Provider；手动刷新时清空以重新拉取。
final confirmedProfileProvider = NotifierProvider<ConfirmedProfile, Json?>(
  ConfirmedProfile.new,
);

/// 已确认档案快照控制器，按登录代次隔离旧账户写入结果。
class ConfirmedProfile extends Notifier<Json?> {
  @override
  Json? build() {
    ref.watch(sessionEpochProvider);
    return null;
  }

  /// 仅当控制器仍挂载且属于发起时的 [session] 代次时写入不可变快照。
  bool accept(Json value, Object? session) {
    if (!ref.mounted || ref.read(sessionEpochProvider) != session) {
      return false;
    }
    state = Map<String, dynamic>.unmodifiable(value);
    return true;
  }

  /// 清空已确认覆盖快照。
  void clear() => state = null;
}

/// 当前用户真实基础档案查询 Provider；优先返回已确认快照，无客户端返回空映射。
final profileProvider = FutureProvider<Json>((ref) async {
  ref.watch(sessionEpochProvider);
  final confirmed = ref.watch(confirmedProfileProvider);
  if (confirmed != null) return confirmed;
  return await ref.watch(profileApiProvider)?.profile() ?? {};
});

/// 按健康类别独立查询真实健康记录列表的 Provider；无客户端时返回空列表。
final healthRecordsProvider = FutureProvider.family<List<Json>, String>(
  (ref, kind) async => await ref.watch(profileApiProvider)?.list(kind) ?? [],
);

/// 同意记录查询别名，复用共享 `consentRecordsProvider`。
final consentsProvider = consentRecordsProvider;
