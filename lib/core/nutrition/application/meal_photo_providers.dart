import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../network/api_client.dart';
import '../../network/object_image_reader.dart';
import '../../session/session_controller.dart';
import '../data/meal_photo.dart';
import 'nutrition_providers.dart';

export '../data/meal_photo.dart';

typedef MealPhotoKey = ({String mealId, String imageId});

final objectImageReaderProvider = Provider.autoDispose<ObjectImageReader>((
  ref,
) {
  ref.watch(sessionEpochProvider);
  final reader = ObjectImageReader();
  ref.onDispose(reader.close);
  return reader;
});

/// 按餐食 ID 缓存的照片元数据加载器，仅保留元数据而不缓存图片字节。
final _photoLoaderProvider = Provider.autoDispose.family<_PhotoLoader, String>((
  ref,
  id,
) {
  final epoch = ref.watch(sessionEpochProvider);
  return _PhotoLoader(
    ref,
    id,
    () => ref.mounted && ref.read(sessionEpochProvider) == epoch,
  );
});

/// 按餐食 ID 共享餐食照片元数据的 Provider；异步返回后检查登录代次。
final mealPhotosProvider = FutureProvider.autoDispose
    .family<MealPhotoSet, String>((ref, id) async {
      final loader = ref.watch(_photoLoaderProvider(id));
      if (ref.read(mealProvider(id)).hasError) ref.invalidate(mealProvider(id));
      // 仅依赖 captureSessionId，避免分析轮询变更餐食其他字段时重建元数据查询。
      final captureId = await ref.watch(
        mealProvider(id).selectAsync((meal) => meal.captureSessionId),
      );
      loader.checkCurrent();
      if (ref.read(captureSessionProvider(captureId)).hasError) {
        ref.invalidate(captureSessionProvider(captureId));
      }
      final session = await ref.watch(captureSessionProvider(captureId).future);
      loader.checkCurrent();
      return loader.fromSession(session);
    }, retry: (count, error) => null);

/// 按餐食与图片 ID 共享照片字节的 Provider；监听释放时取消传输，过期或 401/403 时最多刷新签名一次。
final mealPhotoBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, MealPhotoKey>((ref, key) async {
      final epoch = ref.watch(sessionEpochProvider);
      final loader = ref.watch(_photoLoaderProvider(key.mealId));
      final reader = ref.watch(objectImageReaderProvider);
      final cancel = CancelToken();
      ref.onDispose(() => cancel.cancel());
      // 保留元数据订阅以免重复销毁加载器，但字节加载不随签名刷新重建。
      ref.listen(mealPhotosProvider(key.mealId), (_, _) {});
      void checkCurrent() {
        if (!ref.mounted || ref.read(sessionEpochProvider) != epoch) {
          throw const ApiFailure('会话已更换');
        }
        if (cancel.isCancelled) throw const ApiFailure('照片读取已取消');
      }

      var photos = await ref.read(mealPhotosProvider(key.mealId).future);
      checkCurrent();
      // 链接过期或对象读取返回 401/403 时，单次字节查询最多刷新签名一次。
      var refreshed = false;
      while (true) {
        final photo = photos.photos
            .where((photo) => photo.imageId == key.imageId)
            .firstOrNull;
        if (photo == null) throw const ApiFailure('照片不存在或已被删除');
        final expired =
            photo.expiresAt != null &&
            !photo.expiresAt!.isAfter(DateTime.now().toUtc());
        if (expired && !refreshed) {
          photos = await loader.refresh(photos);
          checkCurrent();
          refreshed = true;
          continue;
        }
        if (expired) throw const ApiFailure('照片链接已失效，请重试');
        if (photo.previewUrl?.isNotEmpty != true) {
          throw const ApiFailure('照片暂不可用，请刷新后重试');
        }
        try {
          final bytes = await reader.read(
            url: photo.previewUrl!,
            cancelToken: cancel,
          );
          checkCurrent();
          return bytes;
        } on ApiFailure catch (error) {
          checkCurrent();
          if (!refreshed && (error.status == 401 || error.status == 403)) {
            photos = await loader.refresh(photos);
            checkCurrent();
            refreshed = true;
            continue;
          }
          rethrow;
        }
      }
    }, retry: (count, error) => null);

class _PhotoLoader {
  _PhotoLoader(this.ref, this.mealId, this.isCurrent);

  final Ref ref;
  final String mealId;
  final bool Function() isCurrent;
  CaptureSession? _session;
  MealPhotoSet? _latest;
  Future<MealPhotoSet>? _refresh;

  void checkCurrent() {
    if (!isCurrent()) throw const ApiFailure('会话已更换');
  }

  /// 从采集会话提取并按槽位排序照片元数据；签名到期时间从响应接收时刻起算。
  MealPhotoSet fromSession(CaptureSession session) {
    checkCurrent();
    if (identical(session, _session)) return _latest!;
    final photos =
        session.images
            .where((image) => image.status == 'confirmed')
            .map(
              (image) => MealPhoto(
                imageId: image.imageId,
                slotNo: image.slotNo,
                previewUrl: image.previewUrl,
                expiresAt: image.previewExpiresInSeconds == null
                    ? null
                    : session.previewReceivedAt.add(
                        Duration(seconds: image.previewExpiresInSeconds!),
                      ),
              ),
            )
            .toList()
          ..sort((a, b) => a.slotNo.compareTo(b.slotNo));
    _session = session;
    return _latest = MealPhotoSet(
      mealId: mealId,
      captureSessionId: session.captureSessionId,
      sessionEpoch: ref.read(sessionEpochProvider),
      photos: photos,
    );
  }

  /// 刷新已过期的照片集合签名；同一餐食并发刷新合并请求并在存在更新快照时直接复用。
  Future<MealPhotoSet> refresh(MealPhotoSet stale) async {
    checkCurrent();
    if (_refresh != null) return _refresh!;
    // 并发照片请求可能已将过期快照替换为最新签名集合。
    if (_latest != null && !identical(stale, _latest)) return _latest!;
    final pending = _reload(stale.captureSessionId);
    _refresh = pending;
    try {
      return await pending;
    } finally {
      _refresh = null;
    }
  }

  Future<MealPhotoSet> _reload(String id) async {
    ref.invalidate(captureSessionProvider(id));
    final session = await ref.read(captureSessionProvider(id).future);
    checkCurrent();
    return fromSession(session);
  }
}
