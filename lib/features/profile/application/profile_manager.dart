import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/account_identity.dart';
import '../../../core/session/session_controller.dart';
import '../data/profile_api.dart';
import 'profile_state.dart';

/// 真实个人资料、健康记录、同意记录与头像操作的统一管理器 Provider。
final profileManagerProvider = Provider<ProfileManager>(ProfileManager.new);

/// 个人资料业务管理器，统一封装刷新与写操作并执行登录代次隔离。
class ProfileManager {
  ProfileManager(this._ref);

  final Ref _ref;

  ProfileApi _requireApi() =>
      _ref.read(profileApiProvider) ?? (throw StateError('会话不可用'));

  bool _isCurrentApi(ProfileApi api, int epoch) =>
      _ref.mounted &&
      _ref.read(sessionEpochProvider) == epoch &&
      identical(api, _ref.read(profileApiProvider));

  /// 清除已确认的本地覆盖并刷新身份、基础资料、五类健康记录与同意记录。
  void refreshAll(Iterable<String> healthKinds) {
    _ref.read(confirmedAvatarProvider.notifier).setUrl(null);
    _ref.read(confirmedProfileProvider.notifier).clear();
    _ref.invalidate(accountIdentityProvider);
    _ref.invalidate(profileProvider);
    refreshHealthCategories(healthKinds);
    _ref.invalidate(consentsProvider);
  }

  /// 刷新共享账户身份查询。
  void refreshIdentity() => _ref.invalidate(accountIdentityProvider);

  /// 刷新基础档案查询。
  void refreshProfile() => _ref.invalidate(profileProvider);

  /// 刷新单个健康记录类别查询。
  void refreshHealthRecords(String kind) =>
      _ref.invalidate(healthRecordsProvider(kind));

  /// 批量刷新多个健康记录类别查询。
  void refreshHealthCategories(Iterable<String> kinds) {
    for (final kind in kinds) {
      _ref.invalidate(healthRecordsProvider(kind));
    }
  }

  /// 刷新同意记录查询。
  void refreshConsents() => _ref.invalidate(consentsProvider);

  /// 保存基础资料并更新已确认档案快照；跨代次结果返回 `false`。
  Future<bool> saveProfile(Json data, {required int epoch}) async {
    final api = _requireApi();
    final saved = await api.saveProfile(data);
    if (!_isCurrentApi(api, epoch)) return false;
    return _ref.read(confirmedProfileProvider.notifier).accept(saved, epoch);
  }

  /// 新增或编辑健康记录，并在仍属于同一代次与 API 时失效该类别缓存。
  Future<bool> saveHealthRecord(
    String kind,
    Json data, {
    String? id,
    required int epoch,
  }) async {
    final api = _requireApi();
    await api.save(kind, data, id: id);
    if (!_isCurrentApi(api, epoch)) return false;
    _ref.invalidate(healthRecordsProvider(kind));
    return true;
  }

  /// 删除指定健康记录，并在仍属于同一代次与 API 时失效该类别缓存。
  Future<bool> deleteHealthRecord(
    String kind,
    String id, {
    required int epoch,
  }) async {
    final api = _requireApi();
    await api.remove(kind, id);
    if (!_isCurrentApi(api, epoch)) return false;
    _ref.invalidate(healthRecordsProvider(kind));
    return true;
  }

  /// 追加一条 AI 营养分析同意或撤回记录，并刷新同意列表。
  Future<bool> submitAiConsent({
    required bool granted,
    required String source,
    required int epoch,
  }) async {
    final api = _requireApi();
    await api.consent(granted, source);
    if (!_isCurrentApi(api, epoch)) return false;
    _ref.invalidate(consentsProvider);
    return true;
  }

  /// 上传裁剪后的头像字节；成功后更新已确认头像地址并刷新账户身份。
  Future<bool> uploadAvatar(
    Uint8List bytes, {
    required void Function(int sent, int total) onProgress,
    required CancelToken cancelToken,
    required int epoch,
  }) async {
    final api = _requireApi();
    final url = await api.uploadAvatar(bytes, onProgress, cancelToken);
    if (!_isCurrentApi(api, epoch)) return false;
    _ref.read(confirmedAvatarProvider.notifier).setUrl(url);
    _ref.invalidate(accountIdentityProvider);
    return true;
  }
}
