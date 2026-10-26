import 'package:diet_auth/diet_auth.dart';
import 'package:diet_client/app/app_shell.dart';
import 'package:diet_client/app/router.dart';
import 'package:diet_client/core/config/ui_preview_config.dart';
import 'package:diet_client/core/nutrition/application/meal_photo_providers.dart';
import 'package:diet_client/core/presentation/app_routes.dart';
import 'package:diet_client/core/presentation/ui_preferences.dart';
import 'package:diet_client/core/session/session_controller.dart';
import 'package:diet_client/features/meal/presentation/screens/native_meal_gallery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySessionStorage implements SessionStorage {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> delete() async {}
}

void main() {
  const mealId = '9007199254740993';
  const imageId = '9007199254740995';

  test('gallery path preserves IDs and contains no signed URL', () {
    expect(
      AppRoutes.mealPhotos(mealId, imageId: imageId),
      '/meals/$mealId/photos?imageId=$imageId',
    );
    expect(AppRoutes.mealPhotos(mealId), '/meals/$mealId/photos');
  });

  testWidgets('signed-out gallery deep link never loads meal photos', (
    tester,
  ) async {
    var loads = 0;
    final container = ProviderContainer(
      overrides: [
        sessionStorageProvider.overrideWithValue(_MemorySessionStorage()),
        persistentUiPreferencesProvider.overrideWithValue(false),
        nativeNutritionEnabledProvider.overrideWithValue(true),
        mealPhotosProvider.overrideWith((ref, id) async {
          loads++;
          return MealPhotoSet(
            mealId: id,
            captureSessionId: 'unused',
            photos: [],
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(sessionStatusProvider.notifier).set(SessionStatus.signedOut);
    final router = container.read(appRouterProvider);
    router.go(AppRoutes.mealPhotos(mealId));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
    expect(find.byType(NativeMealGalleryScreen), findsNothing);
    expect(loads, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('gallery is fullscreen and logout removes it', (tester) async {
    final container = ProviderContainer(
      overrides: [
        sessionStorageProvider.overrideWithValue(_MemorySessionStorage()),
        persistentUiPreferencesProvider.overrideWithValue(false),
        nativeNutritionEnabledProvider.overrideWithValue(true),
        mealPhotosProvider.overrideWith(
          (ref, id) async =>
              MealPhotoSet(mealId: id, captureSessionId: 'unused', photos: []),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(sessionProvider.notifier)
        .establish(
          OidcSession(
            accessToken: 'route-test',
            tokenType: 'Bearer',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        );
    final router = container.read(appRouterProvider);
    router.go(AppRoutes.mealPhotos(mealId, imageId: imageId));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final gallery = tester.widget<NativeMealGalleryScreen>(
      find.byType(NativeMealGalleryScreen),
    );
    expect(gallery.mealId, mealId);
    expect(gallery.imageId, imageId);
    expect(find.byType(AppShell), findsNothing);
    await container.read(sessionProvider.notifier).clear();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
    expect(find.byType(NativeMealGalleryScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Web preview gallery does not construct real photo queries', (
    tester,
  ) async {
    var loads = 0;
    final container = ProviderContainer(
      overrides: [
        sessionStorageProvider.overrideWithValue(_MemorySessionStorage()),
        uiPreviewProvider.overrideWithValue(true),
        nativeNutritionEnabledProvider.overrideWithValue(false),
        persistentUiPreferencesProvider.overrideWithValue(false),
        mealPhotosProvider.overrideWith((ref, id) async {
          loads++;
          return MealPhotoSet(
            mealId: id,
            captureSessionId: 'unused',
            photos: [],
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    router.go(AppRoutes.mealPhotos(mealId));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('此平台暂不支持查看真实餐食照片'), findsOneWidget);
    expect(loads, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
