import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/media/media_coordinator.dart';
import '../../../core/network/api_client.dart';
import '../../../core/nutrition/application/nutrition_providers.dart';
import '../../../core/privacy/ai_consent.dart';
import '../../../core/session/session_controller.dart';

class PendingMealImage {
  PendingMealImage(this.image);
  final SelectedImage image;
  PresignedImage? signed;
  DateTime? signedAt;
  bool uploaded = false;
  CaptureImage? confirmed;
  double progress = 0;
  String get stage => confirmed != null
      ? '已确认'
      : uploaded
      ? '等待确认'
      : signed != null
      ? '等待上传'
      : '待上传';
}

class CaptureFlowState {
  const CaptureFlowState({
    this.session,
    this.pending = const [],
    this.busy = false,
    this.error,
  });
  final CaptureSession? session;
  final List<PendingMealImage> pending;
  final bool busy;
  final String? error;
}

final captureFlowProvider =
    NotifierProvider.autoDispose<CaptureController, CaptureFlowState>(
      CaptureController.new,
    );

class CaptureController extends Notifier<CaptureFlowState> {
  CancelToken? _cancel;
  String? _createKey;
  @override
  CaptureFlowState build() {
    ref.watch(sessionEpochProvider);
    _createKey = null;
    ref.onDispose(() => _cancel?.cancel('采集页面已关闭'));
    return const CaptureFlowState();
  }

  NutriApi get _api =>
      ref.read(nutritionApiProvider) ?? (throw const ApiFailure('请先登录'));
  bool _current(int epoch) =>
      ref.mounted && ref.read(sessionEpochProvider) == epoch;
  void _emit({
    CaptureSession? session,
    List<PendingMealImage>? pending,
    bool? busy,
    String? error,
  }) {
    state = CaptureFlowState(
      session: session ?? state.session,
      pending: pending ?? state.pending,
      busy: busy ?? state.busy,
      error: error,
    );
  }

  Future<T?> _run<T>(Future<T?> Function(int epoch) action) async {
    if (state.busy) return null;
    final epoch = ref.read(sessionEpochProvider);
    _cancel = null;
    _emit(busy: true);
    try {
      return await action(epoch);
    } catch (error) {
      if (_current(epoch)) {
        final cancelled = _cancel?.isCancelled == true;
        _emit(
          error: cancelled
              ? '已取消；已完成的图片保留，可显式重试'
              : error is ApiFailure || error is FormatException
              ? '$error'
              : '操作失败，请检查网络后重试',
        );
        if (error is ApiFailure &&
            error.status == 409 &&
            state.session != null) {
          try {
            final fresh = await _api.captureSession(
              state.session!.captureSessionId,
            );
            if (_current(epoch)) {
              _emit(session: fresh, error: '服务端状态已更新，请核对后重试；本地图片与备注已保留');
            }
          } catch (_) {
            /* Keep the safe local inputs if refresh also fails. */
          }
        }
      }
      return null;
    } finally {
      if (_current(epoch)) _emit(busy: false, error: state.error);
    }
  }

  Future<CaptureSession?> create() => _run((epoch) async {
    _createKey ??= const Uuid().v4();
    final timezone = await ref.read(deviceTimezoneProvider.future);
    if (!_current(epoch)) return null;
    final created = await _api.createCaptureSession(
      timezone: timezone,
      idempotencyKey: _createKey!,
    );
    if (!_current(epoch)) return null;
    _emit(session: created, pending: []);
    _createKey = null;
    invalidateNutrition(ref);
    return created;
  });
  Future<void> open(String id) async {
    await _run((epoch) async {
      final session = await _api.captureSession(id);
      if (!_current(epoch)) return;
      _emit(session: session, pending: []);
      final policy = await ref.read(capturePolicyProvider.future);
      if (!_current(epoch)) return;
      final recovered = await ref
          .read(mediaCoordinatorProvider)
          .recover(purpose: MediaPurpose.meal, contextId: id);
      if (!_current(epoch)) return;
      for (final file in recovered) {
        if (!_current(epoch)) return;
        await _add(file, policy, epoch);
      }
    });
  }

  Future<void> refreshSession() async {
    final id = state.session?.captureSessionId;
    if (id == null) return;
    await _run((epoch) async {
      final fresh = await _api.captureSession(id);
      if (_current(epoch)) _emit(session: fresh);
    });
  }

  Future<void> deleteDraft(String id) async {
    await _run((epoch) async {
      await _api.deleteCaptureSession(id);
      if (!_current(epoch)) return;
      if (state.session?.captureSessionId == id) {
        state = const CaptureFlowState(busy: true);
      }
      invalidateNutrition(ref);
    });
  }

  int get imageCount =>
      (state.session?.images
              .where((image) => image.status != 'deleted')
              .length ??
          0) +
      state.pending
          .where(
            (p) =>
                !(state.session?.images.any(
                      (i) =>
                          i.status != 'deleted' &&
                          i.imageId == p.signed?.imageId,
                    ) ??
                    false),
          )
          .length;
  Future<void> pick(ImageSource source) async {
    if (state.session == null) return;
    await _run((epoch) async {
      final policy = await ref.read(capturePolicyProvider.future);
      if (!_current(epoch)) return;
      final file = await ref
          .read(mediaCoordinatorProvider)
          .pick(
            purpose: MediaPurpose.meal,
            source: source,
            contextId: state.session!.captureSessionId,
          );
      if (!_current(epoch) || file == null) return;
      await _add(file, policy, epoch);
    });
  }

  Future<void> _add(XFile file, CapturePolicy policy, int epoch) async {
    if (imageCount >= policy.maxImageCount ||
        imageCount >= state.session!.maxImageCount) {
      throw const ApiFailure('本餐图片数量已满');
    }
    final image = await ref
        .read(mediaCoordinatorProvider)
        .inspect(
          file,
          maxBytes: policy.maxFileSizeBytes,
          allowedContentTypes: policy.allowedContentTypes,
        );
    if (_current(epoch)) {
      _emit(pending: [...state.pending, PendingMealImage(image)]);
    }
  }

  void cancel() => _cancel?.cancel('用户取消上传');
  Future<void> removePending(PendingMealImage pending) async {
    if (state.busy) return;
    if (pending.signed == null) {
      _emit(pending: state.pending.where((p) => p != pending).toList());
    } else {
      await removeImage(pending.signed!.imageId);
    }
  }

  Future<void> removeImage(String imageId) async {
    final id = state.session?.captureSessionId;
    if (id == null) return;
    await _run((epoch) async {
      await _api.deleteImage(id, imageId);
      if (!_current(epoch)) return;
      _emit(
        pending: state.pending
            .where((p) => p.signed?.imageId != imageId)
            .toList(),
      );
      final fresh = await _api.captureSession(id);
      if (_current(epoch)) {
        _emit(session: fresh);
        invalidateNutrition(ref);
      }
    });
  }

  Future<void> upload() async {
    if (state.session == null) return;
    await _run((epoch) async {
      final id = state.session!.captureSessionId;
      final api = _api;
      final cancel = _cancel = CancelToken();
      for (final pending in state.pending) {
        if (!_current(epoch) || cancel.isCancelled) return;
        if (pending.confirmed != null ||
            state.session!.images.any(
              (i) =>
                  i.imageId == pending.signed?.imageId &&
                  i.status == 'confirmed',
            )) {
          continue;
        }
        final type = pending.image.contentType;
        final extension = switch (type) {
          'image/jpeg' => 'jpg',
          'image/png' => 'png',
          'image/webp' => 'webp',
          _ => throw const FormatException('图片格式不受支持'),
        };
        // Only an explicit upload/retry releases an expired reservation.
        if (pending.signed != null &&
            !pending.uploaded &&
            DateTime.now().difference(pending.signedAt!).inSeconds >=
                pending.signed!.expiresInSeconds) {
          await api.deleteImage(id, pending.signed!.imageId);
          if (!_current(epoch)) return;
          pending.signed = null;
          pending.signedAt = null;
          pending.progress = 0;
          _emit();
          if (cancel.isCancelled) return;
        }
        if (pending.signed == null) {
          final signed = await api.presignImage(
            id,
            fileName: 'meal-${const Uuid().v4()}.$extension',
            contentType: type,
            contentLength: pending.image.bytes.length,
            cancelToken: cancel,
          );
          if (!_current(epoch)) return;
          pending.signed = signed;
          pending.signedAt = DateTime.now();
          _emit();
          if (cancel.isCancelled) return;
        }
        if (!pending.uploaded) {
          await api.uploadImage(
            pending.signed!,
            pending.image.bytes,
            cancelToken: cancel,
            onProgress: (sent, total) {
              if (_current(epoch) && !cancel.isCancelled) {
                pending.progress = total > 0 ? sent / total : 0;
                _emit();
              }
            },
          );
          if (!_current(epoch)) return;
          pending.uploaded = true;
          _emit();
          if (cancel.isCancelled) return;
        }
        final confirmed = await api.confirmImage(
          id,
          pending.signed!.imageId,
          cancelToken: cancel,
        );
        if (!_current(epoch)) return;
        pending.confirmed = confirmed;
        _emit();
        if (cancel.isCancelled) return;
      }
      if (!_current(epoch) || cancel.isCancelled) return;
      final fresh = await api.captureSession(id);
      if (_current(epoch)) {
        _emit(session: fresh);
        invalidateNutrition(ref);
      }
    });
  }

  Future<CaptureSubmission?> submit({
    required String mealType,
    String? notes,
    bool retry = false,
  }) => _run((epoch) async {
    final session = state.session;
    if (session == null) throw const ApiFailure('请先新建或恢复草稿');
    if (state.pending.any(
      (p) =>
          p.confirmed == null &&
          !session.images.any(
            (i) => i.imageId == p.signed?.imageId && i.status == 'confirmed',
          ),
    )) {
      throw const ApiFailure('请先上传并确认全部图片');
    }
    await requireAiNutritionConsent(ref);
    if (!_current(epoch)) return null;
    final result = retry
        ? await _api.retry(session.captureSessionId)
        : await _api.submit(
            session.captureSessionId,
            mealType: mealType,
            notes: notes,
          );
    if (!_current(epoch)) return null;
    _emit(session: result.captureSession);
    invalidateNutrition(ref);
    return result;
  });
}
