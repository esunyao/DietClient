import 'dart:async';
import 'dart:convert';

import 'package:diet_client/core/nutrition/application/meal_photo_providers.dart';
import 'package:diet_client/core/presentation/app_routes.dart';
import 'package:diet_client/core/presentation/ui_preferences.dart';
import 'package:diet_client/features/meal/presentation/screens/native_meal_gallery_screen.dart';
import 'package:diet_client/features/meal/presentation/widgets/meal_photo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _id = '9007199254740993';
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
final _photos = [
  for (var i = 1; i <= 3; i++)
    MealPhoto(
      imageId: 'image-$i',
      slotNo: i,
      previewUrl: 'https://images.test/$i',
    ),
];
MealPhotoSet _set([List<MealPhoto>? photos]) => MealPhotoSet(
  mealId: _id,
  captureSessionId: 'capture',
  photos: photos ?? _photos,
);

Future<({GoRouter router, ProviderContainer container})> _pump(
  WidgetTester tester, {
  String? imageId,
  bool initialGallery = true,
  bool reduceMotion = false,
  bool disableAnimations = false,
  double scale = 1,
  FutureOr<MealPhotoSet> Function()? metadata,
  FutureOr<Uint8List> Function(MealPhotoKey)? bytes,
}) async {
  final container = ProviderContainer(
    overrides: [
      persistentUiPreferencesProvider.overrideWithValue(false),
      mealPhotoPresentationEnabledProvider.overrideWithValue(true),
      mealPhotosProvider.overrideWith((ref, id) => metadata?.call() ?? _set()),
      mealPhotoBytesProvider.overrideWith(
        (ref, key) => bytes?.call(key) ?? _png,
      ),
    ],
  );
  await container
      .read(uiPreferencesProvider.notifier)
      .setReduceMotion(reduceMotion);
  final router = GoRouter(
    initialLocation: initialGallery
        ? AppRoutes.mealPhotos(_id, imageId: imageId)
        : AppRoutes.mealDetail(_id),
    routes: [
      GoRoute(
        path: '/meals/:id',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () =>
                context.push(AppRoutes.mealPhotos(_id, imageId: imageId)),
            child: Text('餐食 ${state.pathParameters['id']}'),
          ),
        ),
      ),
      GoRoute(
        path: '/meals/:id/photos',
        builder: (_, state) => NativeMealGalleryScreen(
          mealId: state.pathParameters['id']!,
          imageId: state.uri.queryParameters['imageId'],
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      key: ValueKey(container),
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  return (router: router, container: container);
}

Future<void> _doubleTap(WidgetTester tester) async {
  final viewer = find.byType(InteractiveViewer).first;
  await tester.tap(viewer);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(viewer);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'known image ID opens its page, unknown image ID falls back to first',
    (tester) async {
      await _pump(tester, imageId: 'image-2');
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      final image = tester.widget<OwnedMealImage>(
        find.byType(OwnedMealImage).first,
      );
      expect(image.decodeWidth, 2048);
      expect(image.fit, BoxFit.contain);
      await _pump(tester, imageId: 'missing');
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
    },
  );

  testWidgets('a large first pointer move still flips the unzoomed page', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(InteractiveViewer).first),
    );
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-520, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('actual horizontal drag flips pages at scale one', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
          .panEnabled,
      isFalse,
    );
    await tester.drag(
      find.byType(InteractiveViewer).first,
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.drag(
      find.byType(InteractiveViewer).first,
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets(
    'double tap zoom prioritizes image pan and blocks swipe and arrow navigation until reset',
    (tester) async {
      await _pump(tester);
      await tester.pumpAndSettle();
      await _doubleTap(tester);
      var viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer).first,
      );
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        closeTo(2.5, .01),
      );
      expect(viewer.panEnabled, isTrue);
      expect(
        tester.widget<PageView>(find.byType(PageView)).physics,
        isA<NeverScrollableScrollPhysics>(),
      );
      final before = viewer.transformationController!.value.clone();
      await tester.drag(
        find.byType(InteractiveViewer).first,
        const Offset(150, 0),
      );
      await tester.pumpAndSettle();
      expect(viewer.transformationController!.value, isNot(before));
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip('下一张'),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await _doubleTap(tester);
      viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer).first,
      );
      expect(viewer.panEnabled, isFalse);
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        closeTo(1, .01),
      );
      await tester.drag(
        find.byType(InteractiveViewer).first,
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
    },
  );

  testWidgets(
    'two pointer pinch zoom disables page swipe and resets by double tap',
    (tester) async {
      await _pump(tester);
      await tester.pumpAndSettle();
      final center = tester.getCenter(find.byType(InteractiveViewer).first);
      final left = await tester.startGesture(
        center - const Offset(40, 0),
        pointer: 1,
      );
      final right = await tester.startGesture(
        center + const Offset(40, 0),
        pointer: 2,
      );
      await tester.pump();
      await left.moveTo(center - const Offset(100, 0));
      await right.moveTo(center + const Offset(100, 0));
      await tester.pump();
      await left.up();
      await right.up();
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer).first,
      );
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(1.01),
      );
      expect(
        tester.widget<PageView>(find.byType(PageView)).physics,
        isA<NeverScrollableScrollPhysics>(),
      );
      expect(find.text('1 / 3'), findsOneWidget);
      await _doubleTap(tester);
      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
            .panEnabled,
        isFalse,
      );
    },
  );

  testWidgets(
    'Windows arrows flip pages and Escape closes with and without a back stack',
    (tester) async {
      await _pump(tester);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('餐食 $_id'), findsOneWidget);
      await tester.tap(find.text('餐食 $_id'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭相册'));
      await tester.pumpAndSettle();
      expect(find.text('餐食 $_id'), findsOneWidget);
    },
  );

  testWidgets('system back without a back stack returns to meal detail', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('餐食 $_id'), findsOneWidget);
  });

  for (final system in [false, true]) {
    testWidgets(
      '${system ? 'system' : 'app'} reduced motion jumps without a paging animation',
      (tester) async {
        await _pump(tester, reduceMotion: !system, disableAnimations: system);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('下一张'));
        await tester.pump();
        expect(
          tester.widget<PageView>(find.byType(PageView)).controller!.page,
          1,
        );
        expect(find.text('2 / 3'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(
          tester.widget<PageView>(find.byType(PageView)).controller!.page,
          0,
        );
      },
    );
  }

  testWidgets('gallery supports metadata retry, byte retry and empty photos', (
    tester,
  ) async {
    var metadataReads = 0, bytesReads = 0;
    await _pump(
      tester,
      metadata: () {
        if (++metadataReads == 1) throw StateError('metadata');
        return _set();
      },
      bytes: (_) {
        if (++bytesReads == 1) throw StateError('bytes');
        return _png;
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('照片信息加载失败，重试'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('照片加载失败，重试'));
    await tester.pumpAndSettle();
    expect(
      find.byType(OwnedMealImage),
      findsWidgets,
      reason: 'metadataReads=$metadataReads bytesReads=$bytesReads',
    );
    expect(metadataReads, 2);
    expect(bytesReads, greaterThanOrEqualTo(2));
    await _pump(tester, metadata: () => _set([]));
    await tester.pumpAndSettle();
    expect(find.text('暂无照片'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets(
    'small landscape and large text keep close, count and navigation reachable',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(tester, scale: 2);
      await tester.pumpAndSettle();
      expect(find.byTooltip('关闭相册'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.tap(find.byTooltip('下一张'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
