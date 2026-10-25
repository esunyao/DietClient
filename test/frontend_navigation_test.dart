import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:diet_auth/diet_auth.dart';
import 'package:diet_client/app/diet_app.dart';
import 'package:diet_client/app/router.dart';
import 'package:diet_client/core/config/api_config.dart';
import 'package:diet_client/core/config/ui_preview_config.dart';
import 'package:diet_client/core/network/api_client.dart';
import 'package:diet_client/core/nutrition/application/nutrition_providers.dart';
import 'package:diet_client/core/presentation/account_identity.dart';
import 'package:diet_client/core/presentation/current_date.dart';
import 'package:diet_client/core/presentation/ui_preferences.dart';
import 'package:diet_client/core/session/session_controller.dart';
import 'package:diet_client/features/profile/application/profile_state.dart';
import 'package:diet_client/features/profile/data/profile_api.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_functional_test.dart' show mealJson;

class _Storage implements SessionStorage {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> delete() async {}
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final FutureOr<Object?> Function(RequestOptions) handler;
  int writes = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    if (options.method != 'GET') writes++;
    return ResponseBody.fromString(
      jsonEncode({'code': 200, 'data': await handler(options)}),
      200,
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  String location,
  _Adapter adapter, {
  DateTime Function()? clock,
}) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final session = OidcSession(
    accessToken: 'test',
    tokenType: 'Bearer',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
  final client = ApiClient(
    config: ApiConfig('https://api.test/'),
    session: session,
    isCurrent: () => true,
    onUnauthorized: () {},
    dio: Dio()..httpClientAdapter = adapter,
  );
  final container = ProviderContainer(
    overrides: [
      if (clock != null) localNowProvider.overrideWithValue(clock),
      sessionStorageProvider.overrideWithValue(_Storage()),
      persistentUiPreferencesProvider.overrideWithValue(false),
      nativeNutritionEnabledProvider.overrideWithValue(true),
      uiPreviewProvider.overrideWithValue(false),
      apiClientProvider.overrideWithValue(null),
      profileApiProvider.overrideWithValue(ProfileApi(client)),
      profileProvider.overrideWith(
        (ref) async => {'userId': 'test', 'heightCm': 164},
      ),
      accountIdentityProvider.overrideWith(
        (ref) async => const AccountIdentity(name: '测试账户'),
      ),
      nutritionApiProvider.overrideWithValue(
        clock == null ? NutriApi(client) : _DateApi(client),
      ),
    ],
  );
  await container.read(sessionProvider.notifier).establish(session);
  await container
      .read(uiPreferencesProvider.notifier)
      .setReduceTransparency(true);
  container.read(appRouterProvider).go(location);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const DietApp()),
  );
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  return container;
}

class _DateApi extends NutriApi {
  _DateApi(super.client);
  final dates = <String>[];
  @override
  Future<DailySummary> dailySummary(String localDate) async {
    dates.add(localDate);
    return DailySummary.fromJson({
      'localDate': localDate,
      'mealCount': 0,
      'nutrients': [],
      'mealBreakdown': [],
      'updatedAt': '2026-10-25T00:00:00Z',
    });
  }

  @override
  Future<MealPage> meals([MealQuery query = defaultMealQuery]) async =>
      MealPage.fromJson({'items': [], 'total': 0, 'page': 1, 'pageSize': 100});
}

void main() {
  testWidgets(
    'profile permission failure gives an actionable message and retains input',
    (tester) async {
      final adapter = _Adapter(
        (request) => throw DioException(
          requestOptions: request,
          response: Response<Object?>(requestOptions: request, statusCode: 403),
          type: DioExceptionType.badResponse,
        ),
      );
      final container = await _pump(tester, '/profile/edit', adapter);
      final field = find.widgetWithText(TextFormField, '身高（cm）');
      await tester.enterText(field, '168');
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存资料'));
      await tester.pumpAndSettle();
      expect(find.text('当前账号无权进行此操作，请确认登录账号或联系管理员，输入已保留。'), findsOneWidget);
      expect(tester.widget<TextFormField>(field).controller!.text, '168');
      expect(adapter.writes, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets('standalone profile save returns after busy guard is released', (
    tester,
  ) async {
    final adapter = _Adapter((_) => {'userId': 'test', 'heightCm': 168});
    final container = await _pump(tester, '/profile/edit', adapter);
    await tester.enterText(find.widgetWithText(TextFormField, '身高（cm）'), '168');
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存资料'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(appRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      '/profile',
    );
    expect(adapter.writes, 1);
    expect(find.text('放弃未保留的修改？'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  testWidgets('delete completion does not pop settings opened while waiting', (
    tester,
  ) async {
    final deleted = Completer<Object?>();
    final adapter = _Adapter(
      (request) => request.method == 'DELETE' ? deleted.future : mealJson(),
    );
    final container = await _pump(tester, '/meals/9007199254740993', adapter);
    await tester.ensureVisible(find.text('删除记录'));
    await tester.tap(find.text('删除记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pump();
    container.read(appRouterProvider).push('/settings');
    await tester.pumpAndSettle();
    expect(find.text('外观设置'), findsOneWidget);
    deleted.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('外观设置'), findsOneWidget);
    expect(adapter.writes, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  testWidgets(
    'home follows midnight and foreground date changes without navigation',
    (tester) async {
      var now = DateTime(2026, 10, 25, 23, 59, 59);
      final container = await _pump(
        tester,
        '/home',
        _Adapter((_) => {}),
        clock: () => now,
      );
      final api = container.read(nutritionApiProvider) as _DateApi;
      expect(api.dates, contains('2026-10-25'));
      now = DateTime(2026, 10, 26);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(api.dates.last, '2026-10-26');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime(2026, 10, 28, 8);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(api.dates.last, '2026-10-28');
      expect(
        container
            .read(appRouterProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .path,
        '/home',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets('expired authentication bypasses dirty form guards', (
    tester,
  ) async {
    final container = await _pump(tester, '/profile/edit', _Adapter((_) => {}));
    await tester.enterText(find.widgetWithText(TextFormField, '身高（cm）'), '168');
    await tester.pumpAndSettle();
    await container.read(sessionProvider.notifier).clear();
    await tester.pumpAndSettle();
    expect(
      container
          .read(appRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      '/login',
    );
    expect(find.text('放弃未保留的修改？'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  testWidgets(
    'real profile edits survive cancelled sidebar navigation; discard exits',
    (tester) async {
      final container = await _pump(
        tester,
        '/profile/edit',
        _Adapter((_) => {}),
      );
      final field = find.widgetWithText(TextFormField, '身高（cm）');
      await tester.ensureVisible(field);
      await tester.enterText(field, '168');
      await tester.pumpAndSettle();
      final router = container.read(appRouterProvider);
      await tester.tap(
        find.byType(AppSideNavigation).evaluate().isNotEmpty
            ? find
                  .descendant(
                    of: find.byType(AppSideNavigation),
                    matching: find.text('配餐'),
                  )
                  .first
            : find.text('配餐').first,
      );
      await tester.pumpAndSettle();
      expect(find.text('放弃未保留的修改？'), findsOneWidget);
      await tester.tap(find.text('继续编辑'));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/profile/edit',
      );
      expect(tester.widget<TextFormField>(field).controller!.text, '168');
      router.go('/meal-plan');
      await tester.pumpAndSettle();
      await tester.tap(find.text('放弃修改'));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/meal-plan');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'saving blocks route replacement and system back until response',
    (tester) async {
      final response = Completer<Object?>();
      final adapter = _Adapter((_) => response.future);
      final container = await _pump(tester, '/profile/edit', adapter);
      await tester.enterText(
        find.widgetWithText(TextFormField, '身高（cm）'),
        '168',
      );
      await tester.tap(find.text('保存资料'));
      await tester.pump();
      final router = container.read(appRouterProvider);
      router.go('/meal-plan');
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/profile/edit',
      );
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.text('放弃未保留的修改？'), findsNothing);
      expect(adapter.writes, 1);
      tester
          .widget<AppSideNavigation>(find.byType(AppSideNavigation))
          .onSettings();
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/profile/edit',
      );
      response.complete({'userId': 'test', 'heightCm': 168});
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'standalone meal deletion navigates to history after exactly one write',
    (tester) async {
      final adapter = _Adapter(
        (request) => request.method == 'DELETE' ? null : mealJson(),
      );
      final container = await _pump(tester, '/meals/9007199254740993', adapter);
      final delete = find.text('删除记录');
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .path,
        '/meals',
      );
      expect(adapter.writes, 1);
      expect(find.textContaining('There is nothing to pop'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('standalone meal correction saves and falls back to its detail', (
    tester,
  ) async {
    final adapter = _Adapter((_) => mealJson());
    final container = await _pump(
      tester,
      '/meals/9007199254740993/correction',
      adapter,
    );
    await tester.enterText(find.widgetWithText(TextField, '本餐备注'), '核对备注');
    await tester.tap(find.text('保存修正'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(appRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      '/meals/9007199254740993',
    );
    expect(adapter.writes, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
