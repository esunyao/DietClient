import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/object_upload.dart';
import '../../../core/privacy/ai_consent.dart';

typedef Json = Map<String, dynamic>;
const healthPaths = {
  'measurement': 'body-measurements',
  'goal': 'health-goals',
  'allergy': 'allergies',
  'disease': 'medical-conditions',
  'restriction': 'dietary-restrictions',
};
const healthIdKeys = {
  'measurement': 'measurementId',
  'goal': 'goalId',
  'allergy': 'allergyId',
  'disease': 'conditionId',
  'restriction': 'restrictionId',
};

/// @brief 真实账户个人资料、健康记录、同意及头像接口封装。
/// @details 业务请求通过 ApiClient 发送，头像对象上传由独立 ObjectUploader 处理。
class ProfileApi {
  ProfileApi(this.client, {Dio? uploadClient})
    : _upload = ObjectUploader(dio: uploadClient);
  final ApiClient client;
  final ObjectUploader _upload;
  Future<Json> profile() async => Map<String, dynamic>.from(
    await client.request('v1/users/self/profile') as Map,
  );

  /// @brief 提交部分更新字段保存用户基础档案。
  /// @param data 待提交的 PATCH 字段映射。
  /// @return 服务端确认后的完整档案 JSON。
  Future<Json> saveProfile(Json data) async => Map<String, dynamic>.from(
    await client.request('v1/users/self/profile', method: 'PATCH', data: data)
        as Map,
  );

  /// @brief 校验健康记录类别与可选 ID 并构造相对接口路径。
  /// @details 类别必须在契约映射内，记录 ID 以纯数字字符串拼入路径，避免数值精度转换。
  /// @param kind 健康记录类别键。
  /// @param id 可选记录数字字符串 ID。
  /// @return 校验通过的健康记录相对路径。
  /// @throws ApiFailure 当类别未知或记录 ID 非纯数字时抛出。
  String _path(String kind, [String? id]) {
    final segment = healthPaths[kind];
    if (segment == null || (id != null && !RegExp(r'^\d+$').hasMatch(id))) {
      throw const ApiFailure('记录不可用');
    }
    return 'v1/users/self/$segment${id == null ? '' : '/$id'}';
  }

  Future<List<Json>> list(String kind) async =>
      (await client.request(_path(kind)) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<Json> save(String kind, Json data, {String? id}) async =>
      Map<String, dynamic>.from(
        await client.request(
          _path(kind, id),
          method: id == null ? 'POST' : 'PATCH',
          data: data,
        ) as Map,
      );
  Future<void> remove(String kind, String id) async {
    await client.request(_path(kind, id), method: 'DELETE');
  }

  Future<List<Json>> consents() async =>
      (await client.request('v1/users/self/consents') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  /// @brief 追加一条 AI 营养分析同意记录。
  /// @details 政策版本固定为 1.0。
  /// @param granted 是否授予同意。
  /// @param source 触发同意记录的来源标识。
  Future<void> consent(bool granted, String source) async {
    await client.request(
      'v1/users/self/consents',
      method: 'POST',
      data: {
        'consentType': 'ai_nutrition_analysis',
        'policyVersion': '1.0',
        'granted': granted,
        'source': source,
      },
    );
  }

  /// @brief 完成头像预签名、对象上传与服务端确认全流程。
  /// @details 先取预签名地址，再由独立上传器执行 PUT，最后向业务接口确认 objectKey；取消令牌传给 PUT，上传前后检查当前会话，PUT 失败统一转换为可重试的安全提示。
  /// @param bytes 已编码的 PNG 头像字节数据。
  /// @param onProgress 上传进度回调（已发送字节数、总字节数）。
  /// @param cancel 用于中断 PUT 上传的取消令牌。
  /// @return 服务端确认后返回的新头像地址，可为 null。
  /// @throws ApiFailure 当会话更换、预签名无效、上传失败或确认失败时抛出。
  Future<String?> uploadAvatar(
    Uint8List bytes,
    void Function(int, int) onProgress,
    CancelToken cancel,
  ) async {
    final presign = await client.request(
      'v1/files/avatar/presign',
      method: 'POST',
      data: {'fileName': 'avatar.png', 'contentType': 'image/png'},
    ) as Json;
    final uri = Uri.tryParse(presign['uploadUrl'] as String? ?? '');
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        !['https', 'http'].contains(uri.scheme)) {
      throw const ApiFailure('上传地址不可用');
    }
    if (!client.isCurrent()) throw const ApiFailure('会话已更换');
    try {
      await _upload.put(
        url: uri.toString(),
        bytes: bytes,
        cancelToken: cancel,
        onProgress: onProgress,
        requiredHeaders: presign['requiredHeaders'] == null
            ? {'Content-Type': 'image/png'}
            : Map<String, String>.from(presign['requiredHeaders'] as Map),
      );
    } catch (_) {
      throw const ApiFailure('头像上传失败，请重试');
    }
    if (!client.isCurrent()) throw const ApiFailure('会话已更换');
    final confirmed = await client.request(
      'v1/files/avatar/confirm',
      method: 'POST',
      data: jsonEncode(presign['objectKey']),
    ) as Json;
    return confirmed['avatarUrl'] as String?;
  }

  /// @brief 释放本 API 实例持有的独立对象上传器。
  void close() => _upload.close();
}

Json? latestConsent(List<Json> records) {
  return latestAiConsent(records);
}

/// @brief 将同意历史列表映射为界面展示用的授权状态文案。
/// @details 使用共享规则选出最新同意记录，再根据政策版本和授权值生成展示状态。
/// @param records 同意历史 JSON 列表。
/// @return 授权状态展示文案（已授权、未授权或需确认新版本）。
String consentStatus(List<Json> records) {
  final latest = latestConsent(records);
  if (latest == null) return '未授权';
  if (latest['policyVersion'] != '1.0') return '需确认新版本';
  return latest['granted'] == true ? '已授权' : '未授权';
}
