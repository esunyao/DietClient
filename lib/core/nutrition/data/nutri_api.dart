import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../data/nutri_models.dart';
import '../../network/api_client.dart';
import '../../network/object_upload.dart';

/// NutriMemo 用户侧采集、餐食和营养汇总接口的薄封装。
/// 业务请求经 ApiClient，对象上传交给独立上传器；不提供演示数据。
class NutriApi {
  NutriApi(this.client, {ObjectUploader? uploader})
    : _uploader = uploader ?? ObjectUploader();
  final ApiClient client;
  final ObjectUploader _uploader;
  static const _base = 'v1/nutri';
  // 路径中的采集会话使用 UUID，餐食和图片等记录使用原样数字字符串。
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
  /// 创建采集会话时发送调用方提供的 UUID 幂等键。
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
  /// 使用预签名地址及指定请求头上传；上传前后检查客户端所属会话。
  /// 取消和进度回调透传给对象上传器，确认图片需另行调用。
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
  /// 部分更新餐食；未提供的字段省略，可在 notes 为 null 时用 clearNotes 显式清空备注。
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
  /// 提交完整修正内容以替换餐食条目；调用方负责写入后的查询失效。
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
  /// 释放本实例使用的对象上传器。
  void close() => _uploader.close();
}
