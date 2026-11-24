import 'dart:async';

import 'package:diet_client/core/config/api_config.dart';
import 'package:diet_client/core/config/ui_preview_config.dart';
import 'package:diet_client/core/network/api_client.dart';
import 'package:diet_client/core/nutrition/application/nutrition_providers.dart';
import 'package:diet_client/core/presentation/app_routes.dart';
import 'package:diet_client/core/presentation/display_state.dart';
import 'package:diet_client/core/presentation/navigation_manager.dart';
import 'package:diet_client/core/presentation/ui_preferences.dart';
import 'package:diet_client/core/presentation/unsaved_form.dart';
import 'package:diet_client/core/privacy/ai_consent.dart';
import 'package:diet_client/core/session/session_controller.dart';
import 'package:diet_client/demo/demo_store.dart';
import 'package:diet_client/features/profile/application/profile_state.dart';
import 'package:diet_client/features/profile/data/profile_api.dart';
import 'package:diet_client/features/settings/application/settings_manager.dart';
import 'package:diet_oidc/diet_oidc.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _NoopAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw UnimplementedError();
  }
}

ApiClient _dummyApiClient() => ApiClient(
  config: ApiConfig('https://api.test/'),
  session: OidcSession(
    accessToken: 'token',
    tokenType: 'Bearer',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  ),
  isCurrent: () => true,
  onUnauthorized: () {},
  dio: Dio()..httpClientAdapter = _NoopAdapter(),
);

Meal _fakeMeal({String id = '10', String status = 'completed'}) =>
    Meal.fromJson({
      'mealId': id,
      'captureSessionId': 'cap-$id',
      'mealType': 'lunch',
      'consumedAt': '2026-11-24T04:30:00Z',
      'localDate': '2026-11-24',
      'timezone': 'Asia/Shanghai',
      'analysisStatus': status,
      'notes': '清蒸鱼',
      'nutrients': const <Object>[],
      'items': const <Object>[],
      'createdAt': '2026-11-24T04:30:00Z',
      'updatedAt': '2026-11-24T04:30:00Z',
    });

CaptureSubmission _fakeSubmission() => CaptureSubmission.fromJson({
  'captureSession': {
    'captureSessionId': 'cap-10',
    'status': 'submitted',
    'timezone': 'Asia/Shanghai',
    'maxImageCount': 3,
    'expiresAt': '2026-11-25T04:30:00Z',
    'analysisRequestedAt': '2026-11-24T04:30:00Z',
    'images': const <Object>[],
    'createdAt': '2026-11-24T04:30:00Z',
    'updatedAt': '2026-11-24T04:30:00Z',
  },
  'meal': {
    'mealId': '10',
    'captureSessionId': 'cap-10',
    'mealType': 'lunch',
    'consumedAt': '2026-11-24T04:30:00Z',
    'localDate': '2026-11-24',
    'timezone': 'Asia/Shanghai',
    'analysisStatus': 'queued',
    'notes': null,
    'nutrients': const <Object>[],
    'items': const <Object>[],
    'createdAt': '2026-11-24T04:30:00Z',
    'updatedAt': '2026-11-24T04:30:00Z',
  },
});

class _FakeNutriApi extends NutriApi {
  _FakeNutriApi() : super(_dummyApiClient());

  int mealCalls = 0;
  int retryCalls = 0;
  int deleteCalls = 0;
  Completer<Meal>? mealCompleter;
  Completer<void>? deleteCompleter;

  @override
  Future<Meal> meal(String id) {
    mealCalls++;
    final pending = mealCompleter;
    if (pending != null) return pending.future;
    return Future.value(_fakeMeal(id: id));
  }

  @override
  Future<void> deleteMeal(String id) async {
    deleteCalls++;
    final pending = deleteCompleter;
    if (pending != null) return pending.future;
  }

  @override
  Future<CaptureSubmission> retry(String captureSessionId) async {
    retryCalls++;
    return _fakeSubmission();
  }
}

class _FakeProfileApi extends ProfileApi {
  _FakeProfileApi() : super(_dummyApiClient());

  Completer<Json>? saveProfileCompleter;
  Completer<void>? removeCompleter;

  @override
  Future<Json> saveProfile(Json data) {
    final pending = saveProfileCompleter;
    if (pending != null) return pending.future;
    return Future.value({...data, 'displayName': data['displayName']});
  }

  @override
  Future<List<Json>> list(String kind) async => const [];

  @override
  Future<void> remove(String kind, String id) {
    final pending = removeCompleter;
    if (pending != null) return pending.future;
    return Future.value();
  }
}

void main() {
  group('AppRoutes 与 nutrition_format', () {
    test('主标签判断、分组索引和路径编码保持规范行为', () {
      expect(AppRoutes.isPrimaryTab(AppRoutes.home), isTrue);
      expect(AppRoutes.isPrimaryTab(AppRoutes.mealPlan), isTrue);
      expect(AppRoutes.isPrimaryTab(AppRoutes.trends), isTrue);
      expect(AppRoutes.isPrimaryTab(AppRoutes.profile), isTrue);
      expect(AppRoutes.isPrimaryTab(AppRoutes.settings), isFalse);

      expect(AppRoutes.tabIndexFor(AppRoutes.home), 0);
      expect(AppRoutes.tabIndexFor(AppRoutes.capture), 0);
      expect(AppRoutes.tabIndexFor(AppRoutes.institutionMenu), 1);
      expect(AppRoutes.tabIndexFor(AppRoutes.mealPlan), 1);
      expect(AppRoutes.tabIndexFor(AppRoutes.trends), 2);
      expect(AppRoutes.tabIndexFor(AppRoutes.reports), 2);
      expect(AppRoutes.tabIndexFor(AppRoutes.profile), 3);
      expect(AppRoutes.tabIndexFor(AppRoutes.settings), 3);

      expect(
        AppRoutes.sessionRestoreLocation('/meals/a b?x=1'),
        '/session/restore?from=%2Fmeals%2Fa%20b%3Fx%3D1',
      );
      expect(AppRoutes.mealDetail('m/1'), '/meals/m%2F1');
      expect(
        AppRoutes.mealPhotos('9007199254740993', imageId: 'img 1'),
        '/meals/9007199254740993/photos?imageId=img+1',
      );
      expect(AppRoutes.mealCorrection('42'), '/meals/42/correction');
      expect(
        AppRoutes.healthRecordForm('goal'),
        '/profile/health-records/goal',
      );
    });

    test('nutrition_format 日期、餐别、状态与数值格式化准确', () {
      expect(formatIsoDate(DateTime(2026, 2, 3)), '2026-02-03');
      expect(mealTypeLabel('lunch'), '午餐');
      expect(mealTypeLabel('custom'), 'custom');

      expect(analysisStatusLabel('queued'), '等待分析');
      expect(analysisStatusLabel('queued', queuedLabel: '待分析'), '待分析');
      expect(analysisStatusLabel('completed'), '已分析');

      expect(captureStatusLabel('created'), '待添加图片');
      expect(captureStatusLabel('uploading'), '正在准备图片');
      expect(captureStatusLabel('analyzing'), '已受理分析');
      expect(captureStatusLabel('failed'), '分析失败，可重新发起');

      expect(formatNutrientAmount(null), '未知');
      expect(formatNutrientAmount(120), '120');
      expect(formatNutrientAmount(19.65), '19.65');
    });
  });

  group('AppNavigationManager 门控与参数透传', () {
    testWidgets('保存阻塞时阻止受保护跳转，空闲时放行并透传 extra', (tester) async {
      var busy = true;
      Map<String, dynamic>? receivedExtra;
      late WidgetRef capturedRef;
      late BuildContext homeContext;

      final router = GoRouter(
        initialLocation: AppRoutes.home,
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) {
              homeContext = context;
              return const Scaffold(body: Text('HOME'));
            },
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const Scaffold(body: Text('SETTINGS')),
          ),
          GoRoute(
            path: AppRoutes.institutionMenu,
            builder: (context, state) => const Scaffold(body: Text('MENU')),
          ),
          GoRoute(
            path: AppRoutes.healthRecordFormPattern,
            builder: (context, state) {
              receivedExtra = state.extra as Map<String, dynamic>?;
              return const Scaffold(body: Text('RECORD_FORM'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final registry = capturedRef.read(routeLeaveRegistryProvider);
      registry.register('form', () async => true, busy: () => busy);
      final navigation = capturedRef.read(navigationManagerProvider);

      navigation.openSettingsGuarded(homeContext);
      navigation.openInstitutionMenuGuarded(homeContext);
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('SETTINGS'), findsNothing);
      expect(find.text('MENU'), findsNothing);

      busy = false;
      navigation.openSettingsGuarded(homeContext);
      await tester.pumpAndSettle();
      expect(find.text('SETTINGS'), findsOneWidget);

      navigation.openHealthRecordForm(
        homeContext,
        'allergy',
        record: {'allergyId': '99', 'allergenName': '花生'},
      );
      await tester.pumpAndSettle();
      expect(find.text('RECORD_FORM'), findsOneWidget);
      expect(receivedExtra?['allergyId'], '99');
    });
  });

  group('NutritionManager、ProfileManager 与 SettingsManager', () {
    test('NutritionManager 未登录拦截、轮询空闲刷新、同意拦截与代次隔离', () async {
      final signedOut = ProviderContainer(
        overrides: [nutritionApiProvider.overrideWithValue(null)],
      );
      addTearDown(signedOut.dispose);
      expect(
        () =>
            signedOut.read(nutritionManagerProvider).deleteMeal('1', epoch: 0),
        throwsA(isA<ApiFailure>()),
      );

      final api = _FakeNutriApi();
      api.mealCompleter = Completer<Meal>();
      var granted = false;
      final container = ProviderContainer(
        overrides: [
          nutritionApiProvider.overrideWithValue(api),
          consentRecordsProvider.overrideWith(
            (ref) async => [
              {
                'consentId': '1',
                'consentType': 'ai_nutrition_analysis',
                'policyVersion': '1.0',
                'granted': granted,
                'recordedAt': '2026-11-24T00:00:00Z',
              },
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      // 查询加载期间，refreshMealIfIdle 不会重复触发加载。
      final mealFuture = container.read(mealProvider('10').future);
      container.read(nutritionManagerProvider).refreshMealIfIdle('10');
      expect(api.mealCalls, 1);
      api.mealCompleter!.complete(_fakeMeal());
      api.mealCompleter = null;
      await mealFuture;

      // 完成后再次轮询会触发重新拉取。
      container.read(nutritionManagerProvider).refreshMealIfIdle('10');
      await container.read(mealProvider('10').future);
      expect(api.mealCalls, 2);

      // AI 同意未开启时禁止 retry，授权开启后放行 retry。
      await expectLater(
        () => container
            .read(nutritionManagerProvider)
            .retryMealAnalysis(_fakeMeal(status: 'failed')),
        throwsA(isA<ApiFailure>()),
      );
      expect(api.retryCalls, 0);

      granted = true;
      await container
          .read(nutritionManagerProvider)
          .retryMealAnalysis(_fakeMeal(status: 'failed'));
      expect(api.retryCalls, 1);

      // 代次切换时，旧删除调用返回 false。
      api.deleteCompleter = Completer<void>();
      final epoch = container.read(sessionEpochProvider);
      final deleteFuture = container
          .read(nutritionManagerProvider)
          .deleteMeal('10', epoch: epoch);
      container.read(sessionEpochProvider.notifier).advance();
      api.deleteCompleter!.complete();
      expect(await deleteFuture, isFalse);
    });

    test('ProfileManager 代次保护与基础资料确认提交', () async {
      final api = _FakeProfileApi();
      final container = ProviderContainer(
        overrides: [profileApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      final epoch0 = container.read(sessionEpochProvider);
      final savedOk = await container.read(profileManagerProvider).saveProfile({
        'displayName': '林小碗',
      }, epoch: epoch0);
      expect(savedOk, isTrue);
      expect(container.read(confirmedProfileProvider)?['displayName'], '林小碗');

      api.removeCompleter = Completer<void>();
      final deleteFuture = container
          .read(profileManagerProvider)
          .deleteHealthRecord('goal', '5', epoch: epoch0);
      container.read(sessionEpochProvider.notifier).advance();
      api.removeCompleter!.complete();
      expect(await deleteFuture, isFalse);
    });

    test('SettingsManager 外观偏好更新、体验模式切换与预览重置隔离', () async {
      final previewContainer = ProviderContainer(
        overrides: [
          uiPreviewProvider.overrideWithValue(true),
          persistentUiPreferencesProvider.overrideWithValue(false),
        ],
      );
      addTearDown(previewContainer.dispose);

      final manager = previewContainer.read(settingsManagerProvider);
      await manager.setGlassMode(GlassMode.off);
      await manager.setMealHistoryLayout(MealHistoryLayout.photoCard);
      manager.selectExperienceMode(ExperienceMode.institution);
      manager.setPrivacyHidden(true);

      expect(
        previewContainer.read(uiPreferencesProvider).glassMode,
        GlassMode.off,
      );
      expect(
        previewContainer.read(uiPreferencesProvider).mealHistoryLayout,
        MealHistoryLayout.photoCard,
      );
      expect(previewContainer.read(demoProvider).isInstitution, isTrue);
      expect(previewContainer.read(demoProvider).privacyHidden, isTrue);

      final message = await manager.resetDefaults();
      expect(message, '内存演示已恢复初始样例');
      expect(previewContainer.read(demoProvider).privacyHidden, isFalse);
      expect(
        previewContainer.read(uiPreferencesProvider).mealHistoryLayout,
        MealHistoryLayout.compact,
      );

      final nativeContainer = ProviderContainer(
        overrides: [uiPreviewProvider.overrideWithValue(false)],
      );
      addTearDown(nativeContainer.dispose);
      final nativeManager = nativeContainer.read(settingsManagerProvider);
      nativeManager.selectExperienceMode(ExperienceMode.institution);
      nativeManager.setPrivacyHidden(true);
      expect(nativeContainer.read(displayStateProvider).isInstitution, isTrue);
      expect(nativeContainer.read(displayStateProvider).privacyHidden, isTrue);
    });
  });
}
