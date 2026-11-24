import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../data/nutri_models.dart';
import '../../network/api_client.dart';
import '../../network/object_upload.dart';

/// NutriMemo 用户侧采集、餐食与营养汇总接口客户端；业务请求走 [ApiClient]，图片上传走 [ObjectUploader]。
class NutriApi {
  NutriApi(this.client, {ObjectUploader? uploader})
    : _uploader = uploader ?? ObjectUploader();
  final ApiClient client;
  final ObjectUploader _uploader;
  static const _base = 'v1/nutri';

  String _capture(String id) {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw const ApiFailure('采集会话不可用');
    }
    return '$_base/capture-sessions/$id';
  }

  String _numeric(String id) {
    if (!RegExp(r'^\d+$').hasMatch(id)) throw const ApiFailure('记录不可用');
    return id;
  }

  Future<NutriJson> _request(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async => nutriJson(
    await client.request(
      path,
      method: method,
      data: data,
      queryParameters: query,
      headers: headers,
      cancelToken: cancelToken,
    ),
  );
  Future<CapturePolicy> capturePolicy() async =>
      CapturePolicy.fromJson(await _request('$_base/capture-policy'));

  /// 创建新的餐食采集会话，使用调用方传入的 UUID 幂等键。
  Future<CaptureSession> createCaptureSession({
    required String timezone,
    required String idempotencyKey,
  }) async {
    _capture(idempotencyKey);
    return CaptureSession.fromJson(
      await _request(
        '$_base/capture-sessions',
        method: 'POST',
        data: {'timezone': timezone},
        headers: {'X-Idempotency-Key': idempotencyKey},
      ),
    );
  }

  Future<CaptureDraftPage> drafts() async => CaptureDraftPage.fromJson(
    await _request('$_base/capture-sessions/drafts'),
  );
  Future<CaptureSession> captureSession(String id) async =>
      CaptureSession.fromJson(await _request(_capture(id)));
  Future<void> deleteCaptureSession(String id) async {
    await client.request(_capture(id), method: 'DELETE');
  }

  Future<PresignedImage> presignImage(
    String sessionId, {
    required String fileName,
    required String contentType,
    required int contentLength,
    DateTime? capturedAt,
    CancelToken? cancelToken,
  }) async => PresignedImage.fromJson(
    await _request(
      '${_capture(sessionId)}/images/presign',
      method: 'POST',
      data: {
        'fileName': fileName,
        'contentType': contentType,
        'contentLength': contentLength,
        if (capturedAt != null)
          'capturedAt': capturedAt.toUtc().toIso8601String(),
      },
      cancelToken: cancelToken,
    ),
  );

  /// 使用预签名地址 PUT 上传采集图片；上传前后校验会话代次，完成后需另行确认图片。
  Future<void> uploadImage(
    PresignedImage image,
    Uint8List bytes, {
    CancelToken? cancelToken,
    ProgressCallback? onProgress,
  }) async {
    if (!client.isCurrent()) throw const ApiFailure('会话已更换');
    await _uploader.put(
      url: image.uploadUrl,
      bytes: bytes,
      requiredHeaders: image.requiredHeaders,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
    if (!client.isCurrent()) throw const ApiFailure('会话已更换');
  }

  Future<CaptureImage> confirmImage(
    String sessionId,
    String imageId, {
    CancelToken? cancelToken,
  }) async => CaptureImage.fromJson(
    await _request(
      '${_capture(sessionId)}/images/${_numeric(imageId)}/confirm',
      method: 'POST',
      cancelToken: cancelToken,
    ),
  );
  Future<void> deleteImage(String sessionId, String imageId) async {
    await client.request(
      '${_capture(sessionId)}/images/${_numeric(imageId)}',
      method: 'DELETE',
    );
  }

  Future<CaptureSubmission> submit(
    String sessionId, {
    required String mealType,
    String? notes,
  }) async => CaptureSubmission.fromJson(
    await _request(
      '${_capture(sessionId)}/submit',
      method: 'POST',
      data: {'mealType': mealType, 'notes': notes},
    ),
  );
  Future<CaptureSubmission> retry(String sessionId) async =>
      CaptureSubmission.fromJson(
        await _request('${_capture(sessionId)}/retry', method: 'POST'),
      );
  Future<MealPage> meals([MealQuery query = defaultMealQuery]) async =>
      MealPage.fromJson(
        await _request(
          '$_base/meals',
          query: {
            if (query.dateFrom != null) 'dateFrom': query.dateFrom,
            if (query.dateTo != null) 'dateTo': query.dateTo,
            if (query.mealType != null) 'mealType': query.mealType,
            if (query.keyword != null) 'q': query.keyword,
            'page': query.page,
            'pageSize': query.pageSize,
          },
        ),
      );
  Future<Meal> meal(String id) async =>
      Meal.fromJson(await _request('$_base/meals/${_numeric(id)}'));

  /// 局部更新餐食基础字段；[clearNotes] 为 `true` 时在 [notes] 为 `null` 的情况下显式清空备注。
  Future<Meal> patchMeal(
    String id, {
    String? mealType,
    DateTime? consumedAt,
    String? timezone,
    String? notes,
    bool clearNotes = false,
  }) async => Meal.fromJson(
    await _request(
      '$_base/meals/${_numeric(id)}',
      method: 'PATCH',
      data: {
        'mealType': ?mealType,
        if (consumedAt != null)
          'consumedAt': consumedAt.toUtc().toIso8601String(),
        'timezone': ?timezone,
        if (notes != null || clearNotes) 'notes': notes,
      },
    ),
  );

  /// 提交完整修正内容以替换餐食菜品条目，调用方负责写入成功后的共享查询刷新。
  Future<Meal> replaceItems(String id, MealCorrection correction) async =>
      Meal.fromJson(
        await _request(
          '$_base/meals/${_numeric(id)}',
          method: 'PUT',
          data: correction.toJson(),
        ),
      );
  Future<void> deleteMeal(String id) async {
    await client.request('$_base/meals/${_numeric(id)}', method: 'DELETE');
  }

  Future<DailySummary> dailySummary(String localDate) async =>
      DailySummary.fromJson(
        await _request(
          '$_base/summaries/daily',
          query: {'localDate': localDate},
        ),
      );
  Future<DailyTrend> dailyTrend(TrendQuery query) async => DailyTrend.fromJson(
    await _request(
      '$_base/summaries/daily-trend',
      query: {'dateFrom': query.dateFrom, 'dateTo': query.dateTo},
    ),
  );

  /// 释放独立对象上传器资源。
  void close() => _uploader.close();
}
