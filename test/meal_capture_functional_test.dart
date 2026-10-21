import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:diet_client/core/media/media_coordinator.dart';
import 'package:diet_client/core/network/api_client.dart';
import 'package:diet_client/core/nutrition/application/nutrition_providers.dart';
import 'package:diet_client/core/privacy/ai_consent.dart';
import 'package:diet_client/core/session/session_controller.dart';
import 'package:diet_client/features/meal_record/application/capture_controller.dart';

const _id = '00000000-0000-4000-8000-000000000001';
Map<String, dynamic> sessionJson({
  List<Map<String, dynamic>> images = const [],
  String status = 'uploading',
}) => {
  'captureSessionId': _id,
  'status': status,
  'timezone': 'Asia/Shanghai',
  'maxImageCount': 3,
  'expiresAt': '2099-01-01T00:00:00Z',
  'createdAt': '2026-01-01T00:00:00Z',
  'updatedAt': '2026-01-01T00:00:00Z',
  'images': images,
};
Map<String, dynamic> imageJson(String id) => {
  'imageId': id,
  'slotNo': int.parse(id),
  'objectKey': 'test/$id',
  'contentType': 'image/png',
  'contentLength': 3,
  'status': 'confirmed',
  'createdAt': '2026-01-01T00:00:00Z',
};

class FakeCaptureApi implements NutriApi {
  final calls = <String>[];
  final keys = <String>[];
  final confirmed = <Map<String, dynamic>>[];
  bool createFails = false, confirmFails = false, putFails = false;
  String? failConfirmId;
  Completer<void>? putWait;
  int nextImage = 0;
  @override
  Future<CaptureSession> createCaptureSession({
    required String timezone,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    if (createFails) throw const ApiFailure('暂不可用');
    return CaptureSession.fromJson(sessionJson());
  }

  @override
  Future<CaptureSession> captureSession(String id) async =>
      CaptureSession.fromJson(sessionJson(images: confirmed));
  @override
  Future<PresignedImage> presignImage(
    String id, {
    required String fileName,
    required String contentType,
    required int contentLength,
    DateTime? capturedAt,
    CancelToken? cancelToken,
  }) async {
    expect(fileName, endsWith('.png'));
    expect(contentType, 'image/png');
    calls.add('presign:${++nextImage}');
    return PresignedImage.fromJson({
      'imageId': '$nextImage',
      'uploadUrl': 'https://upload.test/$nextImage',
      'objectKey': 'test/$nextImage',
      'expiresInSeconds': 300,
      'requiredHeaders': {'Content-Type': contentType},
    });
  }

  @override
  Future<void> uploadImage(
    PresignedImage image,
    Uint8List bytes, {
    CancelToken? cancelToken,
    ProgressCallback? onProgress,
  }) async {
    calls.add('put:${image.imageId}');
    if (putFails) {
      putFails = false;
      throw const ApiFailure('上传失败');
    }
    onProgress?.call(bytes.length, bytes.length);
    await putWait?.future;
    if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
  }

  @override
  Future<CaptureImage> confirmImage(
    String id,
    String imageId, {
    CancelToken? cancelToken,
  }) async {
    calls.add('confirm:$imageId');
    if (confirmFails || failConfirmId == imageId) {
      confirmFails = false;
      failConfirmId = null;
      throw const ApiFailure('确认暂不可用');
    }
    final value = imageJson(imageId);
    confirmed.add(value);
    return CaptureImage.fromJson(value);
  }

  @override
  Future<void> deleteImage(String id, String imageId) async {
    calls.add('delete:$imageId');
    for (final image in confirmed.where(
      (image) => image['imageId'] == imageId,
    )) {
      image['status'] = 'deleted';
    }
  }

  @override
  Future<CaptureSubmission> submit(
    String id, {
    required String mealType,
    String? notes,
  }) async {
    calls.add('submit');
    return CaptureSubmission.fromJson({
      'captureSession': sessionJson(status: 'submitted', images: confirmed),
      'meal': {
        'mealId': '9223372036854775807',
        'mealType': mealType,
        'consumedAt': '2026-01-01T00:00:00Z',
        'localDate': '2026-01-01',
        'analysisStatus': 'queued',
        'nutrients': [],
        'captureSessionId': _id,
        'timezone': 'Asia/Shanghai',
        'items': [],
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-01-01T00:00:00Z',
      },
    });
  }

  @override
  Future<CaptureSubmission> retry(String id) {
    calls.add('retry');
    return submit(id, mealType: 'lunch');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMealMedia implements MediaCoordinator {
  XFile? picked = XFile.fromData(
    Uint8List.fromList([1, 2, 3]),
    name: 'wrong.jpg',
  );
  List<XFile> recovered = [];
  String? recoveryContext;
  @override
  Future<XFile?> pick({
    required MediaPurpose purpose,
    required ImageSource source,
    String? contextId,
  }) async {
    expect(purpose, MediaPurpose.meal);
    expect(contextId, _id);
    return picked;
  }

  @override
  Future<List<XFile>> recover({
    required MediaPurpose purpose,
    String? contextId,
  }) async {
    expect(purpose, MediaPurpose.meal);
    recoveryContext = contextId;
    return recovered;
  }

  @override
  Future<SelectedImage> inspect(
    XFile file, {
    required int maxBytes,
    required List<String> allowedContentTypes,
  }) async => SelectedImage(
    file: file,
    bytes: await file.readAsBytes(),
    contentType: 'image/png',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeCaptureApi api;
  late FakeMealMedia media;
  late ProviderContainer container;
  late CaptureController controller;
  bool granted = true;
  bool consentFails = false;
  String version = '1.0';
  int consentReads = 0;
  setUp(() {
    api = FakeCaptureApi();
    media = FakeMealMedia();
    granted = true;
    consentFails = false;
    version = '1.0';
    consentReads = 0;
    container = ProviderContainer(
      overrides: [
        nutritionApiProvider.overrideWithValue(api),
        mediaCoordinatorProvider.overrideWithValue(media),
        deviceTimezoneProvider.overrideWith((ref) async => 'Asia/Shanghai'),
        capturePolicyProvider.overrideWith(
          (ref) async => CapturePolicy.fromJson({
            'maxImageCount': 3,
            'maxFileSizeBytes': 100,
            'allowedContentTypes': ['image/png'],
            'sessionExpiresInSeconds': 300,
            'maxDraftSessionCount': 5,
            'draftExpiresInSeconds': 300,
          }),
        ),
        consentRecordsProvider.overrideWith((ref) async {
          consentReads++;
          if (consentFails) throw const ApiFailure('授权读取失败');
          return [
            {
              'consentType': 'ai_nutrition_analysis',
              'recordedAt': '2026-01-01T00:00:00Z',
              'consentId': '1',
              'granted': granted,
              'policyVersion': version,
            },
          ];
        }),
      ],
    );
    container.listen(captureFlowProvider, (_, _) {});
    controller = container.read(captureFlowProvider.notifier);
  });
  tearDown(() => container.dispose());
  test('failed create explicitly retries with the same UUID', () async {
    api.createFails = true;
    await controller.create();
    api.createFails = false;
    await controller.create();
    expect(api.keys, hasLength(2));
    expect(api.keys[0], api.keys[1]);
    expect(api.keys[0], matches(RegExp(r'^[0-9a-f-]{36}$')));
  });
  test('cancelled picker never uploads', () async {
    await controller.create();
    media.picked = null;
    await controller.pick(ImageSource.gallery);
    expect(container.read(captureFlowProvider).pending, isEmpty);
    expect(api.calls, isEmpty);
  });
  test(
    'serial presign PUT confirm; failed confirm retries only that stage',
    () async {
      await controller.create();
      await controller.pick(ImageSource.gallery);
      await controller.pick(ImageSource.gallery);
      api.confirmFails = true;
      await controller.upload();
      expect(api.calls, ['presign:1', 'put:1', 'confirm:1']);
      expect(
        container.read(captureFlowProvider).pending.first.uploaded,
        isTrue,
      );
      await controller.upload();
      expect(api.calls, [
        'presign:1',
        'put:1',
        'confirm:1',
        'confirm:1',
        'presign:2',
        'put:2',
        'confirm:2',
      ]);
      expect(container.read(captureFlowProvider).session!.images, hasLength(2));
    },
  );
  test('upload cancel does not confirm and preserves selected photo', () async {
    await controller.create();
    await controller.pick(ImageSource.gallery);
    api.putWait = Completer<void>();
    final upload = controller.upload();
    await Future<void>.delayed(Duration.zero);
    controller.cancel();
    api.putWait!.complete();
    await upload;
    expect(api.calls, ['presign:1', 'put:1']);
    expect(container.read(captureFlowProvider).pending, hasLength(1));
    expect(container.read(captureFlowProvider).busy, isFalse);
  });
  test(
    'confirmed first photo is never uploaded again after second photo fails',
    () async {
      await controller.create();
      await controller.pick(ImageSource.gallery);
      await controller.pick(ImageSource.gallery);
      api.failConfirmId = '2';
      await controller.upload();
      expect(
        container.read(captureFlowProvider).pending.first.confirmed,
        isNotNull,
      );
      await controller.upload();
      expect(api.calls, [
        'presign:1',
        'put:1',
        'confirm:1',
        'presign:2',
        'put:2',
        'confirm:2',
        'confirm:2',
      ]);
    },
  );
  test('policy count blocks a fourth selection without uploading', () async {
    await controller.create();
    for (var index = 0; index < 4; index++) {
      await controller.pick(ImageSource.gallery);
    }
    expect(container.read(captureFlowProvider).pending, hasLength(3));
    expect(container.read(captureFlowProvider).error, contains('数量已满'));
    expect(api.calls, isEmpty);
  });
  test('deleted server images release the policy slots', () async {
    api.confirmed.addAll([
      for (var index = 1; index <= 3; index++)
        {...imageJson('$index'), 'status': 'deleted'},
    ]);
    await controller.open(_id);
    expect(controller.imageCount, 0);
    await controller.pick(ImageSource.gallery);
    expect(controller.imageCount, 1);
    expect(container.read(captureFlowProvider).pending, hasLength(1));
  });
  test(
    'explicit expired signature retry keeps bytes and replaces reservation',
    () async {
      await controller.create();
      await controller.pick(ImageSource.gallery);
      final pending = container.read(captureFlowProvider).pending.single;
      api.putFails = true;
      await controller.upload();
      pending.signedAt = DateTime.now().subtract(const Duration(hours: 1));
      await controller.upload();
      expect(
        container.read(captureFlowProvider).pending.single.image,
        same(pending.image),
      );
      expect(api.calls, [
        'presign:1',
        'put:1',
        'delete:1',
        'presign:2',
        'put:2',
        'confirm:2',
      ]);
    },
  );
  test('failed consent read blocks submission without server writes', () async {
    await controller.create();
    await controller.pick(ImageSource.gallery);
    await controller.upload();
    consentFails = true;
    expect(await controller.submit(mealType: 'lunch'), isNull);
    expect(api.calls, isNot(contains('submit')));
    expect(container.read(captureFlowProvider).busy, isFalse);
  });
  test(
    'every submit/retry checks current consent; old version and revoked block',
    () async {
      await controller.create();
      await controller.pick(ImageSource.gallery);
      await controller.upload();
      granted = false;
      expect(await controller.submit(mealType: 'lunch'), isNull);
      granted = true;
      version = '0.9';
      expect(await controller.submit(mealType: 'lunch', retry: true), isNull);
      expect(
        api.calls.where((call) => call == 'submit' || call == 'retry'),
        isEmpty,
      );
      version = '1.0';
      final result = await controller.submit(mealType: 'lunch');
      expect(result!.meal.analysisStatus, 'queued');
      expect(result.meal.mealId, '9223372036854775807');
      expect(consentReads, 3);
    },
  );
  test('recovered photo uses session context and stays pending', () async {
    media.recovered = [media.picked!];
    await controller.open(_id);
    expect(media.recoveryContext, _id);
    expect(container.read(captureFlowProvider).pending, hasLength(1));
    expect(api.calls, isEmpty);
  });
  test(
    'account change cancels pending upload and ignores old completion',
    () async {
      await controller.create();
      await controller.pick(ImageSource.gallery);
      api.putWait = Completer<void>();
      final upload = controller.upload();
      await Future<void>.delayed(Duration.zero);
      container.read(sessionEpochProvider.notifier).advance();
      expect(container.read(captureFlowProvider).session, isNull);
      api.putWait!.complete();
      await upload;
      expect(container.read(captureFlowProvider).session, isNull);
      expect(container.read(captureFlowProvider).pending, isEmpty);
      expect(api.calls, ['presign:1', 'put:1']);
    },
  );
}
