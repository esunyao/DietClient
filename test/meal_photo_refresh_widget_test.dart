import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:diet_client/core/network/api_client.dart';
import 'package:diet_client/core/network/object_image_reader.dart';
import 'package:diet_client/core/nutrition/application/meal_photo_providers.dart';
import 'package:diet_client/core/nutrition/application/nutrition_providers.dart';
import 'package:diet_client/core/presentation/ui_preferences.dart';
import 'package:diet_client/core/session/session_controller.dart';
import 'package:diet_client/features/meal/presentation/screens/native_meal_gallery_screen.dart';
import 'package:diet_client/features/meal/presentation/widgets/meal_photo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _mealId = '9007199254740993';
const _captureId = '12345678-1234-1234-1234-123456789012';
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

Meal _meal() => Meal.fromJson({
  'mealId': _mealId,
  'captureSessionId': _captureId,
  'mealType': 'lunch',
  'consumedAt': '2026-10-26T04:00:00Z',
  'localDate': '2026-10-26',
  'timezone': 'Asia/Shanghai',
  'analysisStatus': 'completed',
  'items': [],
  'nutrients': [],
  'createdAt': '2026-10-26T04:00:00Z',
  'updatedAt': '2026-10-26T04:00:00Z',
});
CaptureSession _capture() => CaptureSession.fromJson({
  'captureSessionId': _captureId,
  'status': 'completed',
  'timezone': 'Asia/Shanghai',
  'maxImageCount': 10,
  'expiresAt': '2027-01-01T00:00:00Z',
  'createdAt': '2026-10-26T04:00:00Z',
  'updatedAt': '2026-10-26T04:00:00Z',
  'images': [
    {
      'imageId': '9007199254740995',
      'slotNo': 1,
      'objectKey': 'test/photo.png',
      'contentType': 'image/png',
      'contentLength': _png.length,
      'status': 'confirmed',
      'createdAt': '2026-10-26T04:00:00Z',
      'previewUrl': 'https://objects.test/photo',
      'previewExpiresInSeconds': 300,
    },
  ],
});

class _Reader extends ObjectImageReader {
  _Reader({this.reject = true});
  final bool reject;
  int reads = 0;
  @override
  Future<Uint8List> read({
    required String url,
    CancelToken? cancelToken,
  }) async {
    reads++;
    if (reject) throw const ApiFailure('expired', status: 403);
    return _png;
  }
}

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  final surfaces = <String, Widget Function()>{
    'history cover': () => SizedBox(
      width: 200,
      height: 140,
      child: MealPhotoCover(mealId: _mealId, onOpen: (_) {}),
    ),
    'detail strip': () =>
        const SizedBox(width: 360, child: MealPhotoStrip(mealId: _mealId)),
    'fullscreen gallery': () => const NativeMealGalleryScreen(mealId: _mealId),
  };
  for (final entry in surfaces.entries) {
    testWidgets(
      'slow signature refresh keeps the retry budget on ${entry.key}',
      (tester) async {
        var captureReads = 0;
        final renewal = Completer<CaptureSession>();
        final reader = _Reader();
        final container = ProviderContainer(
          overrides: [
            persistentUiPreferencesProvider.overrideWithValue(false),
            mealPhotoPresentationEnabledProvider.overrideWithValue(true),
            mealProvider.overrideWith((ref, id) async => _meal()),
            captureSessionProvider.overrideWith((ref, id) {
              captureReads++;
              return captureReads == 2
                  ? renewal.future
                  : Future.value(_capture());
            }),
            objectImageReaderProvider.overrideWith((ref) => reader),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(reader.close);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(body: Center(child: entry.value())),
            ),
          ),
        );
        await _frames(tester);
        expect(captureReads, 2);
        expect(reader.reads, 1);
        renewal.complete(_capture());
        await _frames(tester, 24);
        final actualCaptureReads = captureReads,
            actualObjectReads = reader.reads;
        await tester.pumpWidget(const SizedBox.shrink());
        await _frames(tester, 2);
        expect(
          actualCaptureReads,
          2,
          reason: 'persistent 403 must not start another signature renewal',
        );
        expect(
          actualObjectReads,
          2,
          reason: 'one initial GET and one bounded retry',
        );
      },
    );
  }

  testWidgets(
    'account switch clears old photos while new metadata is pending',
    (tester) async {
      var reads = 0;
      final nextOwner = Completer<CaptureSession>();
      final reader = _Reader(reject: false);
      final container = ProviderContainer(
        overrides: [
          persistentUiPreferencesProvider.overrideWithValue(false),
          mealPhotoPresentationEnabledProvider.overrideWithValue(true),
          mealProvider.overrideWith((ref, id) async => _meal()),
          captureSessionProvider.overrideWith((ref, id) {
            ref.watch(sessionEpochProvider);
            reads++;
            return reads == 1 ? Future.value(_capture()) : nextOwner.future;
          }),
          objectImageReaderProvider.overrideWith((ref) => reader),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(reader.close);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: Center(child: surfaces['history cover']!())),
          ),
        ),
      );
      await _frames(tester);
      expect(find.byType(OwnedMealImage), findsOneWidget);
      container.read(sessionEpochProvider.notifier).advance();
      await _frames(tester);
      expect(find.byType(OwnedMealImage), findsNothing);
      nextOwner.complete(_capture());
      await _frames(tester);
      expect(find.byType(OwnedMealImage), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
