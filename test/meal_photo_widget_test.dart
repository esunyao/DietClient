import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:diet_client/core/nutrition/application/meal_photo_providers.dart';
import 'package:diet_client/core/nutrition/application/nutrition_providers.dart';
import 'package:diet_client/core/presentation/app_routes.dart';
import 'package:diet_client/core/presentation/ui_preferences.dart';
import 'package:diet_client/core/session/session_controller.dart';
import 'package:diet_client/features/meal/presentation/screens/native_meal_detail_screen.dart';
import 'package:diet_client/features/meal/presentation/screens/native_meal_history_screen.dart';
import 'package:diet_client/features/meal/presentation/widgets/meal_photo_widgets.dart';
import 'package:diet_client/features/meal/presentation/widgets/native_meal_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
const _id = '9007199254740993';
const _photo = MealPhoto(
  imageId: 'image-1',
  slotNo: 1,
  previewUrl: 'https://images.test/one',
);
MealPhotoSet _set([List<MealPhoto> photos = const [_photo]]) =>
    MealPhotoSet(mealId: _id, captureSessionId: 'capture', photos: photos);
Map<String, Object?> _meal(String id) => {
  'mealId': id,
  'mealType': 'lunch',
  'consumedAt': '2026-10-26T12:00:00+08:00',
  'localDate': '2026-10-26',
  'analysisStatus': 'completed',
  'nutrients': [],
  'notes': '本餐备注',
  'captureSessionId': 'capture',
  'timezone': 'Asia/Shanghai',
  'items': [],
  'createdAt': '2026-10-26T04:00:00Z',
  'updatedAt': '2026-10-26T04:00:00Z',
};

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget child, {
  FutureOr<MealPhotoSet> Function(String)? metadata,
  FutureOr<Uint8List> Function(MealPhotoKey)? bytes,
  bool enabled = true,
  double scale = 1,
}) async {
  final container = ProviderContainer(
    overrides: [
      mealPhotoPresentationEnabledProvider.overrideWithValue(enabled),
      persistentUiPreferencesProvider.overrideWithValue(false),
      mealPhotosProvider.overrideWith(
        (ref, id) => metadata?.call(id) ?? _set(),
      ),
      mealPhotoBytesProvider.overrideWith(
        (ref, key) => bytes?.call(key) ?? _png,
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      key: ValueKey(container),
      container: container,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  testWidgets(
    'a legacy UI without a session never starts the photo metadata provider',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          mealPhotosProvider.overrideWith(
            (ref, id) => throw StateError('unexpected photo metadata request'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          key: ValueKey(container),
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox.square(
                dimension: 96,
                child: MealPhotoCover(mealId: _id, onOpen: (_) {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂无照片'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'metadata and bytes load independently, then show count and bounded decode',
    (tester) async {
      final metadata = Completer<MealPhotoSet>();
      final bytes = Completer<Uint8List>();
      await _pump(
        tester,
        SizedBox.square(
          dimension: 96,
          child: MealPhotoCover(mealId: _id, onOpen: (_) {}),
        ),
        metadata: (_) => metadata.future,
        bytes: (_) => bytes.future,
      );
      expect(find.text('读取信息'), findsOneWidget);
      metadata.complete(_set());
      await tester.pump();
      await tester.pump();
      expect(find.text('加载中'), findsOneWidget);
      bytes.complete(_png);
      await tester.pumpAndSettle();
      expect(find.text('1 张'), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<ResizeImage>(),
      );
      expect(
        (tester.widget<Image>(find.byType(Image)).image as ResizeImage).width,
        288,
      );
    },
  );

  testWidgets('empty URL retries metadata without requesting bytes', (
    tester,
  ) async {
    var reads = 0, byteReads = 0;
    await _pump(
      tester,
      SizedBox.square(
        dimension: 96,
        child: MealPhotoCover(mealId: _id, onOpen: (_) {}),
      ),
      metadata: (_) {
        reads++;
        return _set(const [MealPhoto(imageId: 'image-1', slotNo: 1)]);
      },
      bytes: (_) {
        byteReads++;
        return _png;
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('链接缺失'), findsOneWidget);
    expect(byteReads, 0);
    await tester.tap(find.byTooltip('照片链接暂不可用，重试'));
    await tester.pumpAndSettle();
    expect(reads, 2);
  });

  testWidgets('metadata error and byte error retry their own providers', (
    tester,
  ) async {
    var metadataReads = 0, byteReads = 0;
    await _pump(
      tester,
      SizedBox.square(
        dimension: 96,
        child: MealPhotoCover(mealId: _id, onOpen: (_) {}),
      ),
      metadata: (_) {
        if (++metadataReads == 1) throw StateError('metadata');
        return _set();
      },
      bytes: (_) {
        if (++byteReads == 1) throw StateError('bytes');
        return _png;
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('信息失败'), findsOneWidget);
    await tester.tap(find.byTooltip('照片信息加载失败，重试'));
    await tester.pumpAndSettle();
    expect(find.text('加载失败'), findsOneWidget);
    await tester.tap(find.byTooltip('照片加载失败，重试'));
    await tester.pumpAndSettle();
    expect(metadataReads, 2);
    expect(byteReads, 2);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('corrupt image can retry bytes without reloading metadata', (
    tester,
  ) async {
    var byteReads = 0, metadataReads = 0;
    await _pump(
      tester,
      const SizedBox.square(
        dimension: 96,
        child: MealPhotoImage(mealId: _id, photo: _photo, decodeWidth: 288),
      ),
      metadata: (_) {
        metadataReads++;
        return _set();
      },
      bytes: (_) => ++byteReads == 1 ? Uint8List.fromList([1, 2, 3]) : _png,
    );
    await tester.pumpAndSettle();
    expect(find.text('图片损坏'), findsOneWidget);
    await tester.tap(find.byTooltip('照片无法显示，重试'));
    await tester.pumpAndSettle();
    expect(byteReads, 2);
    expect(metadataReads, 0);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('empty photos and disabled session do not read image bytes', (
    tester,
  ) async {
    var reads = 0;
    await _pump(
      tester,
      SizedBox.square(
        dimension: 96,
        child: MealPhotoCover(mealId: _id, onOpen: (_) {}),
      ),
      metadata: (_) => _set([]),
      bytes: (_) {
        reads++;
        return _png;
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无照片'), findsOneWidget);
    expect(reads, 0);
    await _pump(
      tester,
      SizedBox.square(
        dimension: 96,
        child: MealPhotoCover(mealId: _id, onOpen: (_) {}),
      ),
      enabled: false,
      metadata: (_) => throw StateError('no session must not request metadata'),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无照片'), findsOneWidget);
  });

  testWidgets(
    'compact statuses keep visible text at large text scale without overflow',
    (tester) async {
      for (final label in ['暂无照片', '读取照片信息', '照片加载失败', '照片链接暂不可用']) {
        await _pump(
          tester,
          SizedBox.square(
            dimension: 96,
            child: MealPhotoStatus(
              label: label,
              loading: label == '读取照片信息',
              retry: label.contains('失败') || label.contains('链接')
                  ? () {}
                  : null,
            ),
          ),
          scale: 3,
        );
        expect(find.byType(Text), findsWidgets);
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final layout in MealHistoryLayout.values) {
    testWidgets('$layout fits a narrow phone with large text', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(
        tester,
        NativeMealTile(
          meal: MealHistoryItem.fromJson(_meal(_id)),
          onTap: () {},
          onPhotoTap: (_) {},
          layout: layout,
        ),
        scale: 2,
      );
      await tester.pumpAndSettle();
      expect(find.text('未知 kcal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$layout separates photo route from detail text and preserves unknown energy',
      (tester) async {
        String? opened;
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: NativeMealTile(
                  meal: MealHistoryItem.fromJson(_meal(_id)),
                  layout: layout,
                  onTap: () => context.push(AppRoutes.mealDetail(_id)),
                  onPhotoTap: (id) =>
                      context.push(AppRoutes.mealPhotos(_id, imageId: id)),
                ),
              ),
            ),
            GoRoute(
              path: '/meals/:id',
              builder: (_, state) => Text('详情 ${state.pathParameters['id']}'),
            ),
            GoRoute(
              path: '/meals/:id/photos',
              builder: (_, state) {
                opened = state.uri.queryParameters['imageId'];
                return const Text('相册');
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mealPhotoPresentationEnabledProvider.overrideWithValue(true),
              mealPhotosProvider.overrideWith((ref, id) => _set()),
              mealPhotoBytesProvider.overrideWith((ref, key) => _png),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('未知 kcal'), findsOneWidget);
        if (layout == MealHistoryLayout.compact) {
          expect(
            tester.getSize(find.byType(MealPhotoCover)),
            const Size(96, 96),
          );
        }
        await tester.tap(find.byType(Image));
        await tester.pumpAndSettle();
        expect(opened, 'image-1');
        expect(find.text('相册'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('本餐备注'));
        await tester.pumpAndSettle();
        expect(find.text('详情 $_id'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'history only mounts visible photo consumers, scroll loads more',
    (tester) async {
      final requested = <String>{};
      final container = ProviderContainer(
        overrides: [
          persistentUiPreferencesProvider.overrideWithValue(false),
          mealPhotoPresentationEnabledProvider.overrideWithValue(true),
          mealsProvider.overrideWith(
            (ref, query) => MealPage.fromJson({
              'items': List.generate(20, (i) => _meal('${i + 1}')),
              'page': 1,
              'pageSize': 20,
              'total': 20,
            }),
          ),
          mealPhotosProvider.overrideWith((ref, id) {
            requested.add(id);
            return _set([]);
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: NativeMealHistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(requested.length, lessThan(20));
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(requested, isNotEmpty);
      expect(requested.length, lessThan(20));
      expect(find.text('未知 kcal'), findsWidgets);
    },
  );

  testWidgets(
    'analysis pending detail shows photos and opens the selected image',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/meals/$_id',
        routes: [
          GoRoute(
            path: '/meals/:id',
            builder: (_, _) => const NativeMealDetailScreen(mealId: _id),
          ),
          GoRoute(
            path: '/meals/:id/photos',
            builder: (_, state) =>
                Text('照片 ${state.uri.queryParameters['imageId']}'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mealPhotoPresentationEnabledProvider.overrideWithValue(true),
            mealProvider(_id).overrideWith(
              (ref) =>
                  Meal.fromJson({..._meal(_id), 'analysisStatus': 'pending'}),
            ),
            mealPhotosProvider.overrideWith(
              (ref, id) => _set([
                _photo,
                const MealPhoto(
                  imageId: 'image-2',
                  slotNo: 2,
                  previewUrl: 'https://images.test/two',
                ),
              ]),
            ),
            mealPhotoBytesProvider.overrideWith((ref, key) => _png),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('等待分析'), findsOneWidget);
      await tester.ensureVisible(find.byType(MealPhotoStrip));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is MealPhotoImage && widget.photo.imageId == 'image-2',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('照片 image-2'), findsOneWidget);
    },
  );

  testWidgets(
    'owned cache entries are distinct and eviction preserves other images',
    (tester) async {
      final unrelated = MemoryImage(Uint8List.fromList(_png));
      await _pump(
        tester,
        Row(
          children: [
            SizedBox.square(
              dimension: 96,
              child: MealPhotoImage(
                mealId: _id,
                photo: _photo,
                decodeWidth: 288,
              ),
            ),
            SizedBox.square(dimension: 96, child: Image(image: unrelated)),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final owned = tester
          .widget<Image>(
            find.descendant(
              of: find.byType(OwnedMealImage),
              matching: find.byType(Image),
            ),
          )
          .image;
      final ownedKey = await owned.obtainKey(ImageConfiguration.empty);
      final otherKey = await unrelated.obtainKey(ImageConfiguration.empty);
      expect(ownedKey, isNot(otherKey));
      expect(PaintingBinding.instance.imageCache.containsKey(ownedKey), isTrue);
      await tester.pumpWidget(MaterialApp(home: Image(image: unrelated)));
      await tester.pumpAndSettle();
      expect(
        PaintingBinding.instance.imageCache.containsKey(ownedKey),
        isFalse,
      );
      expect(PaintingBinding.instance.imageCache.containsKey(otherKey), isTrue);
      await unrelated.evict();
    },
  );

  testWidgets('account epoch releases the old owned cache entry', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      const SizedBox.square(
        dimension: 96,
        child: MealPhotoImage(mealId: _id, photo: _photo, decodeWidth: 288),
      ),
    );
    await tester.pumpAndSettle();
    final old = tester.widget<Image>(find.byType(Image)).image;
    final oldKey = await old.obtainKey(ImageConfiguration.empty);
    container.read(sessionEpochProvider.notifier).advance();
    await tester.pumpAndSettle();
    expect(PaintingBinding.instance.imageCache.containsKey(oldKey), isFalse);
    expect(tester.widget<Image>(find.byType(Image)).image, isNot(same(old)));
  });
}
