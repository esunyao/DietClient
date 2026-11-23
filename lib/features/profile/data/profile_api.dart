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

/// 封装真实账户的资料、健康记录、同意和头像请求；对象上传由独立上传器处理。
class ProfileApi {
  ProfileApi(this.client, {Dio? uploadClient})
    : _upload = ObjectUploader(dio: uploadClient);
  final ApiClient client;
  final ObjectUploader _upload;
  Future<Json> profile() async => Map<String, dynamic>.from(
    await client.request('v1/users/self/profile') as Map,
  );
  /// 提交调用方提供的 PATCH 字段，返回服务端确认的档案。
  Future<Json> saveProfile(Json data) async => Map<String, dynamic>.from(
    await client.request('v1/users/self/profile', method: 'PATCH', data: data)
        as Map,
  );
  // 类别必须在契约映射内，记录 ID 以数字字符串拼入路径，避免数值精度转换。
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
  /// 追加 AI 营养分析同意记录，政策版本固定为 1.0。
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

  /// 先取预签名地址，再由独立上传器 PUT，最后向业务接口确认 objectKey。
  /// 取消令牌传给 PUT；上传前后检查当前会话，PUT 失败统一转换为可重试的安全提示。
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

  /// 释放此 API 持有的对象上传器。
  void close() => _upload.close();
}

Json? latestConsent(List<Json> records) {
  return latestAiConsent(records);
}

/// 使用共享规则选出最新同意，再根据政策版本和授权值生成展示状态。
String consentStatus(List<Json> records) {
  final latest = latestConsent(records);
  if (latest == null) return '未授权';
  if (latest['policyVersion'] != '1.0') return '需确认新版本';
  return latest['granted'] == true ? '已授权' : '未授权';
}
