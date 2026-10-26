import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:diet_client/core/network/api_client.dart';
import 'package:diet_client/core/network/object_image_reader.dart';
import 'package:diet_client/core/nutrition/application/meal_photo_providers.dart';
import 'package:diet_client/core/nutrition/application/nutrition_providers.dart';
import 'package:diet_client/core/session/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _mealId = '9223372036854775807';
const _captureId = 'd9754967-5141-4b64-b971-ab83e623c3e6';
const _imageId = '9223372036854775806';
const _key = (mealId: _mealId, imageId: _imageId);

Meal _meal({String status = 'queued'}) => Meal.fromJson({
  'mealId': _mealId,
  'captureSessionId': _captureId,
  'mealType': 'lunch',
  'consumedAt': '2026-01-01T00:00:00Z',
  'localDate': '2026-01-01',
  'analysisStatus': status,
  'timezone': 'Asia/Shanghai',
  'nutrients': [],
  'items': [],
  'createdAt': '2026-01-01T00:00:00Z',
  'updatedAt': '2026-01-01T00:00:00Z',
});

Map<String, dynamic> _image({
  String id = _imageId,
  int slot = 1,
  String status = 'confirmed',
  String? url = 'https://objects.test/old',
  int? seconds = 300,
}) => {
  'imageId': id,
  'slotNo': slot,
  'objectKey': 'test/$id',
  'contentType': 'image/jpeg',
  'contentLength': 3,
  'status': status,
  'createdAt': '2026-01-01T00:00:00Z',
  'previewUrl': url,
  'previewExpiresInSeconds': seconds,
};

CaptureSession _session(List<Map<String, dynamic>> images) =>
    CaptureSession.fromJson({
      'captureSessionId': _captureId,
      'status': 'submitted',
      'timezone': 'Asia/Shanghai',
      'maxImageCount': 3,
      'expiresAt': '2026-01-02T00:00:00Z',
      'images': images,
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-01T00:00:00Z',
    });

class _Reader implements ObjectImageReader {
  Future<Uint8List> Function(String, CancelToken?)? handler;
  final urls = <String>[];
  final cancellations = <CancelToken?>[];
  var closed = false;

  @override
  Future<Uint8List> read({
    required String url,
    CancelToken? cancelToken,
  }) async {
    urls.add(url);
    cancellations.add(cancelToken);
    return handler == null
        ? Uint8List.fromList([1, 2, 3])
        : handler!(url, cancelToken);
  }

  @override
  void close() => closed = true;
}

class _Fixture {
  _Fixture() {
    container = ProviderContainer(
      overrides: [
        mealProvider(_mealId).overrideWith((ref) {
          ref.watch(sessionEpochProvider);
          mealReads++;
          return mealHandler?.call() ?? _meal();
        }),
        captureSessionProvider(_captureId).overrideWith((ref) {
          ref.watch(sessionEpochProvider);
          captureReads++;
          return captureHandler?.call() ?? _session([_image()]);
        }),
        objectImageReaderProvider.overrideWith((ref) {
          ref.watch(sessionEpochProvider);
          ref.onDispose(reader.close);
          return reader;
        }),
      ],
    );
  }

  final reader = _Reader();
  late final ProviderContainer container;
  int mealReads = 0, captureReads = 0;
  FutureOr<Meal> Function()? mealHandler;
  FutureOr<CaptureSession> Function()? captureHandler;

  Future<MealPhotoSet> photos() {
    container.listen(mealPhotosProvider(_mealId), (_, _) {});
    return container.read(mealPhotosProvider(_mealId).future);
  }

  Future<Uint8List> bytes([MealPhotoKey key = _key]) {
    container.listen(mealPhotoBytesProvider(key), (_, _) {});
    return container.read(mealPhotoBytesProvider(key).future);
  }

  void close() => container.dispose();
}

void main() {
  late _Fixture fixture;
  setUp(() => fixture = _Fixture());
  tearDown(() => fixture.close());

  test(
    'confirmed photos sort by slot with exact IDs and immutable collection',
    () async {
      fixture.captureHandler = () => _session([
        _image(id: '3', slot: 3),
        _image(id: '4', slot: 0, status: 'reserved'),
        _image(id: '5', slot: 0, status: 'deleted'),
        _image(slot: 1),
        _image(id: '2', slot: 2, url: null, seconds: null),
      ]);
      final set = await fixture.photos();
      expect(set.mealId, _mealId);
      expect(set.captureSessionId, _captureId);
      expect(set.photos.map((photo) => photo.imageId), [_imageId, '2', '3']);
      expect(set.photos[1].previewUrl, isNull);
      expect(set.photos[1].expiresAt, isNull);
      expect(() => set.photos.clear(), throwsUnsupportedError);
    },
  );

  test('empty capture is a genuine empty photo set', () async {
    fixture.captureHandler = () => _session([]);
    expect((await fixture.photos()).photos, isEmpty);
    await expectLater(fixture.bytes(), throwsA(isA<ApiFailure>()));
    expect(fixture.reader.urls, isEmpty);
  });

  test(
    'missing preview remains unavailable without fake bytes or retry storm',
    () async {
      fixture.captureHandler = () => _session([_image(url: null)]);
      await expectLater(fixture.bytes(), throwsA(isA<ApiFailure>()));
      await fixture.container.pump();
      expect(fixture.captureReads, 1);
      expect(fixture.reader.urls, isEmpty);
    },
  );

  test(
    'metadata error is visible and explicit invalidate retries it',
    () async {
      fixture.captureHandler = () => throw const ApiFailure('采集会话暂不可用');
      await expectLater(fixture.photos(), throwsA(isA<ApiFailure>()));
      fixture.captureHandler = () => _session([_image()]);
      fixture.container.invalidate(mealPhotosProvider(_mealId));
      expect((await fixture.photos()).photos.single.imageId, _imageId);
    },
  );

  test('TTL is anchored to response receipt when metadata is reused', () async {
    final session = _session([_image(seconds: 60)]);
    fixture.captureHandler = () => session;
    final first = await fixture.photos();
    expect(
      first.photos.single.expiresAt,
      session.previewReceivedAt.add(const Duration(seconds: 60)),
    );
    fixture.container.invalidate(mealPhotosProvider(_mealId));
    final second = await fixture.photos();
    expect(second.photos.single.expiresAt, first.photos.single.expiresAt);
    expect(fixture.captureReads, 1);
  });

  test('listeners share metadata and downloaded bytes', () async {
    final results = await Future.wait([
      fixture.bytes(),
      fixture.bytes(),
      fixture.photos(),
    ]);
    expect(results[0], same(results[1]));
    expect(fixture.mealReads, 1);
    expect(fixture.captureReads, 1);
    expect(fixture.reader.urls, hasLength(1));
  });

  test(
    'analysis polling and metadata refresh never redownload active bytes',
    () async {
      await fixture.bytes();
      for (final status in ['running', 'succeeded', 'failed']) {
        fixture.mealHandler = () => _meal(status: status);
        fixture.container.invalidate(mealProvider(_mealId));
        await fixture.container.read(mealProvider(_mealId).future);
        await fixture.container.pump();
        expect(
          fixture.container.read(mealPhotoBytesProvider(_key)).requireValue,
          [1, 2, 3],
        );
      }
      fixture.captureHandler = () =>
          _session([_image(url: 'https://objects.test/new')]);
      fixture.container.invalidate(captureSessionProvider(_captureId));
      await fixture.container.read(captureSessionProvider(_captureId).future);
      await fixture.container.pump();
      expect(fixture.reader.urls, ['https://objects.test/old']);
      expect(fixture.mealReads, 4);
      expect(fixture.captureReads, 2);
    },
  );

  test('expired metadata refreshes once before any object GET', () async {
    fixture.captureHandler = () => _session([
      _image(
        url: 'https://objects.test/${fixture.captureReads}',
        seconds: fixture.captureReads == 1 ? -1 : 300,
      ),
    ]);
    expect(await fixture.bytes(), [1, 2, 3]);
    expect(fixture.captureReads, 2);
    expect(fixture.reader.urls, ['https://objects.test/2']);
  });

  for (final status in [401, 403]) {
    test(
      '$status refreshes once without rebuilding watched byte providers',
      () async {
        fixture.captureHandler = () => _session([
          _image(url: 'https://objects.test/${fixture.captureReads}'),
        ]);
        fixture.reader.handler = (url, _) async {
          if (url.endsWith('/1')) throw ApiFailure('照片链接已失效', status: status);
          return Uint8List.fromList([4, 5]);
        };
        expect(await fixture.bytes(), [4, 5]);
        await fixture.container.pump();
        expect(fixture.captureReads, 2);
        expect(fixture.reader.urls, hasLength(2));
      },
    );

    test(
      'persistent $status stops after exactly one retry per byte provider',
      () async {
        fixture.reader.handler = (_, _) async =>
            throw ApiFailure('失效', status: status);
        await expectLater(fixture.bytes(), throwsA(isA<ApiFailure>()));
        await fixture.container.pump();
        expect(fixture.captureReads, 2);
        expect(fixture.reader.urls, hasLength(2));
      },
    );
  }

  test(
    'parallel 401/403, including a late old rejection, share one refresh',
    () async {
      final oldReads = [Completer<Uint8List>(), Completer<Uint8List>()];
      var dispatched = 0;
      fixture.captureHandler = () => _session([
        for (final id in [_imageId, '2'])
          _image(
            id: id,
            url: 'https://objects.test/${fixture.captureReads}/$id',
          ),
      ]);
      fixture.reader.handler = (url, _) async => url.contains('/1/')
          ? oldReads[dispatched++].future
          : Uint8List.fromList([9]);
      final result = Future.wait([
        fixture.bytes(),
        fixture.bytes((mealId: _mealId, imageId: '2')),
      ]);
      await fixture.container.pump();
      oldReads[0].completeError(const ApiFailure('失效', status: 401));
      await fixture.container.pump();
      expect(fixture.captureReads, 2);
      oldReads[1].completeError(const ApiFailure('失效', status: 403));
      await result;
      expect(fixture.captureReads, 2);
      expect(fixture.reader.urls, hasLength(4));
    },
  );

  test(
    'simultaneously expired photos join an in-flight metadata refresh',
    () async {
      final renewed = Completer<CaptureSession>();
      fixture.captureHandler = () => fixture.captureReads == 1
          ? _session([_image(seconds: -1), _image(id: '2', seconds: -1)])
          : renewed.future;
      final result = Future.wait([
        fixture.bytes(),
        fixture.bytes((mealId: _mealId, imageId: '2')),
      ]);
      await fixture.container.pump();
      expect(fixture.captureReads, 2);
      renewed.complete(_session([_image(), _image(id: '2')]));
      await result;
      expect(fixture.captureReads, 2);
      expect(fixture.reader.urls, hasLength(2));
    },
  );

  test('still-expired refreshed metadata stops without a GET', () async {
    fixture.captureHandler = () => _session([_image(seconds: -1)]);
    await expectLater(fixture.bytes(), throwsA(isA<ApiFailure>()));
    expect(fixture.captureReads, 2);
    expect(fixture.reader.urls, isEmpty);
  });

  test(
    'expiry refresh consumes the only retry even if the new GET is 403',
    () async {
      fixture.captureHandler = () =>
          _session([_image(seconds: fixture.captureReads == 1 ? -1 : 300)]);
      fixture.reader.handler = (_, _) async =>
          throw const ApiFailure('失效', status: 403);
      await expectLater(fixture.bytes(), throwsA(isA<ApiFailure>()));
      await fixture.container.pump();
      expect(fixture.captureReads, 2);
      expect(fixture.reader.urls, hasLength(1));
    },
  );

  test(
    'parallel persistent denials stop after one retry for each image',
    () async {
      fixture.captureHandler = () => _session([_image(), _image(id: '2')]);
      fixture.reader.handler = (_, _) async =>
          throw const ApiFailure('失效', status: 403);
      await Future.wait([
        expectLater(fixture.bytes(), throwsA(isA<ApiFailure>())),
        expectLater(
          fixture.bytes((mealId: _mealId, imageId: '2')),
          throwsA(isA<ApiFailure>()),
        ),
      ]);
      await fixture.container.pump();
      expect(fixture.captureReads, 2);
      expect(fixture.reader.urls, hasLength(4));
    },
  );

  test('manual byte invalidate retries a failed object request', () async {
    fixture.reader.handler = (_, _) async =>
        throw const ApiFailure('照片暂不可用', status: 500);
    await expectLater(fixture.bytes(), throwsA(isA<ApiFailure>()));
    fixture.reader.handler = null;
    fixture.container.invalidate(mealPhotoBytesProvider(_key));
    expect(await fixture.bytes(), [1, 2, 3]);
    expect(fixture.captureReads, 1);
    expect(fixture.reader.urls, hasLength(2));
  });

  test(
    'last listener disposal cancels bytes and releases metadata and reader',
    () async {
      final pending = Completer<Uint8List>();
      fixture.reader.handler = (_, _) => pending.future;
      final listener = fixture.container.listen(
        mealPhotoBytesProvider(_key),
        (_, _) {},
      );
      await fixture.container.pump();
      expect(fixture.reader.urls, hasLength(1));
      listener.close();
      for (var i = 0; i < 5; i++) {
        await fixture.container.pump();
      }
      expect(fixture.reader.cancellations.single!.isCancelled, isTrue);
      expect(fixture.reader.closed, isTrue);
      expect(fixture.container.exists(mealPhotoBytesProvider(_key)), isFalse);
      expect(fixture.container.exists(mealPhotosProvider(_mealId)), isFalse);
      pending.complete(Uint8List.fromList([7]));
      await fixture.container.pump();
    },
  );

  test(
    'successful bytes are released and fetched anew after leaving the page',
    () async {
      final listener = fixture.container.listen(
        mealPhotoBytesProvider(_key),
        (_, _) {},
      );
      await fixture.container.read(mealPhotoBytesProvider(_key).future);
      listener.close();
      for (var i = 0; i < 5; i++) {
        await fixture.container.pump();
      }
      expect(fixture.container.exists(mealPhotoBytesProvider(_key)), isFalse);
      await fixture.bytes();
      expect(fixture.reader.urls, hasLength(2));
    },
  );

  test('account switch cancels old download and refuses late bytes', () async {
    final pending = Completer<Uint8List>();
    fixture.reader.handler = (_, _) => fixture.reader.urls.length == 1
        ? pending.future
        : Future.value(Uint8List.fromList([9]));
    final seen = <Uint8List>[];
    fixture.container.listen(mealPhotoBytesProvider(_key), (_, next) {
      if (next is AsyncData<Uint8List>) seen.add(next.value);
    });
    await fixture.container.pump();
    fixture.container.read(sessionEpochProvider.notifier).advance();
    await fixture.container.pump();
    expect(fixture.reader.cancellations.first!.isCancelled, isTrue);
    expect(await fixture.container.read(mealPhotoBytesProvider(_key).future), [
      9,
    ]);
    pending.complete(Uint8List.fromList([7]));
    await fixture.container.pump();
    expect(seen, isNot(contains(orderedEquals([7]))));
    expect(fixture.container.read(mealPhotoBytesProvider(_key)).requireValue, [
      9,
    ]);
  });

  test(
    'account switch drops late meal metadata before capture is requested',
    () async {
      final oldMeal = Completer<Meal>();
      fixture.mealHandler = () =>
          fixture.mealReads == 1 ? oldMeal.future : _meal();
      fixture.container.listen(mealPhotosProvider(_mealId), (_, _) {});
      await fixture.container.pump();
      fixture.container.read(sessionEpochProvider.notifier).advance();
      await fixture.photos();
      final reads = fixture.captureReads;
      oldMeal.complete(_meal());
      await fixture.container.pump();
      expect(fixture.captureReads, reads);
    },
  );

  test(
    'leaving during meal lookup drops late metadata before capture lookup',
    () async {
      final pending = Completer<Meal>();
      fixture.mealHandler = () => pending.future;
      final listener = fixture.container.listen(
        mealPhotosProvider(_mealId),
        (_, _) {},
      );
      await fixture.container.pump();
      listener.close();
      for (var i = 0; i < 5; i++) {
        await fixture.container.pump();
      }
      pending.complete(_meal());
      await fixture.container.pump();
      expect(fixture.captureReads, 0);
      expect(fixture.container.exists(mealPhotosProvider(_mealId)), isFalse);
    },
  );

  test(
    'account switch drops late signed metadata and never downloads old URL',
    () async {
      final oldSession = Completer<CaptureSession>();
      fixture.captureHandler = () => fixture.captureReads == 1
          ? oldSession.future
          : _session([_image(url: 'https://objects.test/new-account')]);
      final seen = <MealPhotoSet>[];
      fixture.container.listen(mealPhotosProvider(_mealId), (_, next) {
        if (next is AsyncData<MealPhotoSet>) seen.add(next.value);
      });
      fixture.container.listen(mealPhotoBytesProvider(_key), (_, _) {});
      await fixture.container.pump();
      fixture.container.read(sessionEpochProvider.notifier).advance();
      expect(await fixture.bytes(), [1, 2, 3]);
      oldSession.complete(
        _session([_image(url: 'https://objects.test/old-account')]),
      );
      await fixture.container.pump();
      expect(
        seen.every(
          (set) => set.photos.single.previewUrl!.endsWith('/new-account'),
        ),
        isTrue,
      );
      expect(fixture.reader.urls, ['https://objects.test/new-account']);
    },
  );
}
