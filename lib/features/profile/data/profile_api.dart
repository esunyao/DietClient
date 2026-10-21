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

class ProfileApi {
  ProfileApi(this.client, {Dio? uploadClient})
    : _upload = ObjectUploader(dio: uploadClient);
  final ApiClient client;
  final ObjectUploader _upload;
  Future<Json> profile() async => Map<String, dynamic>.from(
    await client.request('v1/users/self/profile') as Map,
  );
  Future<Json> saveProfile(Json data) async => Map<String, dynamic>.from(
    await client.request('v1/users/self/profile', method: 'PATCH', data: data)
        as Map,
  );
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

  void close() => _upload.close();
}

Json? latestConsent(List<Json> records) {
  return latestAiConsent(records);
}

String consentStatus(List<Json> records) {
  final latest = latestConsent(records);
  if (latest == null) return '未授权';
  if (latest['policyVersion'] != '1.0') return '需确认新版本';
  return latest['granted'] == true ? '已授权' : '未授权';
}
