import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/media/media_coordinator.dart';
import '../../../core/network/api_client.dart';
import '../../../core/nutrition/application/nutrition_providers.dart';
import '../../../core/privacy/ai_consent.dart';
import '../../../core/session/session_controller.dart';

/// @brief 本页内存中的待处理餐食图片及上传阶段状态模型。
/// @details 失败重试时复用已完成的签名、上传或确认结果。
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

/// @brief 餐食采集流程聚合状态模型。
/// @details 聚合服务端采集会话、本地待处理图片、忙碌标记与错误信息；备注输入由页面持有。
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

/// @brief 真实餐食采集流程控制器。
/// @details 协调真实采集 API、媒体选择和授权检查，并按登录代次隔离异步结果。
class CaptureController extends Notifier<CaptureFlowState> {
  CancelToken? _cancel;
  String? _createKey;
  @override
  CaptureFlowState build() {
    // 登录代次变化时重建状态；销毁时取消当前上传请求。
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

  /// @brief 在互斥保护下执行单个异步采集操作。
  /// @details 仅在控制器仍挂载且登录代次未变时回写错误和忙碌状态；发生冲突时尝试刷新服务端会话并保留本地输入供核对。
  /// @param action 接收当前登录代次的异步业务操作。
  /// @return 操作返回值；若已有操作进行中或捕获异常则返回 null。
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
            (error.status == 409 || error.code == 409) &&
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

  /// @brief 创建新的服务端餐食采集会话。
  /// @details 新建失败后的显式重试复用同一幂等键；成功后清除该键并失效共享营养查询。
  /// @return 创建成功的采集会话；失败或会话更换时返回 null。
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

  /// @brief 打开并恢复指定的服务端采集草稿。
  /// @details 同时通过媒体协调器按餐食用途和会话 ID 恢复 Android 可能丢失的选图结果。
  /// @param id 目标采集会话 ID。
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

  /// @brief 计算当前采集会话中的有效图片总数。
  /// @details 合并未删除的服务端图片和本地待处理图片，按签名图片 ID 去重计数。
  /// @return 当前已计入上限的图片数量。
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

  /// @brief 校验并向待上传队列追加单张图片。
  /// @details 同时遵守策略和会话的数量上限；文件内容、大小及类型交由媒体协调器检查。
  /// @param file 待加入的本地图片文件。
  /// @param policy 服务端采集策略。
  /// @param epoch 发起操作时的登录代次。
  /// @throws ApiFailure 当本餐图片数量已达上限时抛出。
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

  /// @brief 串行执行本地待处理图片的预签名、上传和确认流程。
  /// @details 重试时自动跳过已完成的阶段，并向对象上传流程传递取消令牌。
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

  /// @brief 提交采集会话或触发重新分析。
  /// @details 确认全部本地图片已上传确认，并每次都向服务端重新核实 AI 同意；成功后失效共享营养查询。
  /// @param mealType 餐别标识。
  /// @param notes 可选餐食备注。
  /// @param retry 是否为失败后的重新分析提交，默认为 false。
  /// @return 服务端返回的采集受理结果；未通过检查或失败时返回 null。
  /// @note 返回受理结果不代表分析已完成，具体分析结果需另行查看。
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
