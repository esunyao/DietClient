import 'dart:async';

import 'package:diet_client/core/media/media_coordinator.dart';
import 'package:diet_client/core/network/api_client.dart';
import 'package:diet_client/core/nutrition/application/nutrition_providers.dart';
import 'package:diet_client/core/privacy/ai_consent.dart';
import 'package:diet_client/features/home/presentation/screens/native_home_screen.dart';
import 'package:diet_client/features/meal/presentation/screens/native_meal_correction_screen.dart';
import 'package:diet_client/features/meal_record/application/capture_controller.dart';
import 'package:diet_client/features/meal_record/presentation/screens/native_recognition_screen.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'meal_capture_functional_test.dart' as capture;
import 'meal_functional_test.dart' as fixture;

const _captureId = '00000000-0000-4000-8000-000000000001';
const _mealId = '9007199254740993';

// Reuse the existing in-memory media/session fixtures. Unexpected API methods
// throw instead of falling through to an external service.
class _LayoutApi extends capture.FakeCaptureApi {
  bool writeFails = true, summaryFails = false, mealsFail = false;
  Completer<void>? submissionWait;
  int submissions = 0, patches = 0, summaryReads = 0, mealReads = 0;
  final submittedNotes = <String?>[];
  final patchedNotes = <String?>[];

  @override
  Future<CapturePolicy> capturePolicy() async => CapturePolicy.fromJson({
    'maxImageCount': 3,
    'maxFileSizeBytes': 10485760,
    'allowedContentTypes': ['image/png', 'image/jpeg'],
    'sessionExpiresInSeconds': 300,
    'maxDraftSessionCount': 5,
    'draftExpiresInSeconds': 300,
  });

  @override
  Future<CaptureDraftPage> drafts() async =>
      CaptureDraftPage.fromJson({'items': [], 'total': 0});

  @override
  Future<CaptureSession> captureSession(String id) async =>
      CaptureSession.fromJson(
        capture.sessionJson(images: [capture.imageJson('1')]),
      );

  @override
  Future<CaptureSubmission> submit(
    String id, {
    required String mealType,
    String? notes,
  }) async {
    submissions++;
    submittedNotes.add(notes);
    if (submissionWait != null) await submissionWait!.future;
    if (writeFails) throw const ApiFailure('分析提交失败，请重试');
    return super.submit(id, mealType: mealType, notes: notes);
  }

  @override
  Future<Meal> meal(String id) async => Meal.fromJson(fixture.mealJson());

  @override
  Future<Meal> patchMeal(
    String id, {
    String? mealType,
    DateTime? consumedAt,
    String? timezone,
    String? notes,
    bool clearNotes = false,
  }) async {
    patches++;
    patchedNotes.add(notes);
    if (writeFails) throw const ApiFailure('保存失败，请重试');
    return Meal.fromJson({...fixture.mealJson(), 'notes': notes});
  }

  @override
  Future<DailySummary> dailySummary(String localDate) async {
    summaryReads++;
    if (summaryFails) throw const ApiFailure('今日营养读取失败');
    return DailySummary.fromJson({
      'localDate': localDate,
      'mealCount': 1,
      'nutrients': [],
      'mealBreakdown': [],
      'updatedAt': '2026-10-20T04:00:00Z',
    });
  }

  @override
  Future<MealPage> meals([MealQuery query = defaultMealQuery]) async {
    mealReads++;
    if (mealsFail) throw const ApiFailure('今日餐食读取失败');
    return MealPage.fromJson({
      'items': [
        {...fixture.mealJson(), 'notes': '真实记录保留较长的菜名与备注用于窄屏回归'},
      ],
      'total': 1,
      'page': query.page,
      'pageSize': query.pageSize,
    });
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget page,
  _LayoutApi api, {
  Size size = const Size(320, 740),
  double textScale = 1.5,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  final router = GoRouter(
    initialLocation: '/screen',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('已返回')),
        routes: [GoRoute(path: 'screen', builder: (_, _) => page)],
      ),
      GoRoute(
        path: '/consent',
        builder: (_, _) => const Scaffold(body: Text('授权页面')),
      ),
      GoRoute(
        path: '/meals/:id',
        builder: (_, _) => const Scaffold(body: Text('已受理餐食')),
      ),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(null),
      nutritionApiProvider.overrideWithValue(api),
      mediaCoordinatorProvider.overrideWithValue(capture.FakeMealMedia()),
      deviceTimezoneProvider.overrideWith((ref) async => 'Asia/Shanghai'),
      consentRecordsProvider.overrideWith(
        (ref) async => [
          {
            'consentType': 'ai_nutrition_analysis',
            'recordedAt': '2026-01-01T00:00:00Z',
            'consentId': '1',
            'granted': true,
            'policyVersion': '1.0',
          },
        ],
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
}

void main() {
  testWidgets(
    'busy capture disables consent entry and completion never replaces a covering route',
    (tester) async {
      final api = _LayoutApi()
        ..writeFails = false
        ..submissionWait = Completer<void>();
      final container = await _pump(
        tester,
        const NativeRecognitionScreen(),
        api,
      );
      await container.read(captureFlowProvider.notifier).open(_captureId);
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('提交并分析'));
      await tester.tap(find.text('提交并分析'));
      await tester.pump();
      await _reveal(tester, find.text('AI 营养分析已授权'));
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'AI 营养分析已授权'))
            .onTap,
        isNull,
      );
      final router = GoRouter.of(
        tester.element(find.byType(NativeRecognitionScreen)),
      );
      router.push('/consent');
      await tester.pumpAndSettle();
      api.submissionWait!.complete();
      await tester.pumpAndSettle();
      expect(find.text('授权页面'), findsOneWidget);
      expect(find.text('已受理餐食'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'native capture narrow large text: submission failure retains notes and reachable retry',
    (tester) async {
      final api = _LayoutApi();
      final container = await _pump(
        tester,
        const NativeRecognitionScreen(),
        api,
      );
      await container.read(captureFlowProvider.notifier).open(_captureId);
      await tester.pumpAndSettle();
      final notes = find.widgetWithText(TextField, '备注（选填）');
      await _reveal(tester, notes);
      await tester.enterText(notes, '少油，保留这条备注');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      final submit = find.text('提交并分析');
      await _reveal(tester, submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.submissions, 1);
      await _reveal(tester, notes);
      expect(tester.widget<TextField>(notes).controller!.text, '少油，保留这条备注');
      await _reveal(tester, find.text('分析提交失败，请重试'));
      expect(find.text('分析提交失败，请重试'), findsOneWidget);
      expect(tester.takeException(), isNull);
      api.writeFails = false;
      await _reveal(tester, submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.submittedNotes, ['少油，保留这条备注', '少油，保留这条备注']);
      expect(find.text('已受理餐食'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'native correction landscape keyboard: failed save keeps input and footer retry returns',
    (tester) async {
      final api = _LayoutApi();
      await _pump(
        tester,
        const NativeMealCorrectionScreen(mealId: _mealId),
        api,
        size: const Size(844, 390),
        textScale: 1.3,
      );
      final notes = find.widgetWithText(TextField, '本餐备注');
      await _reveal(tester, notes);
      await tester.enterText(notes, '保存失败也不丢失');
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      await tester.pumpAndSettle();
      final save = find.text('保存修正');
      await _reveal(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(api.patches, 1);
      await _reveal(tester, notes);
      expect(tester.widget<TextField>(notes).controller!.text, '保存失败也不丢失');
      await _reveal(tester, find.text('保存失败，请重试'));
      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(tester.takeException(), isNull);
      api.writeFails = false;
      await _reveal(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(api.patchedNotes, ['保存失败也不丢失', '保存失败也不丢失']);
      expect(find.text('已返回'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'native correction 320px large text: item input and footer remain reachable',
    (tester) async {
      final api = _LayoutApi();
      await _pump(
        tester,
        const NativeMealCorrectionScreen(mealId: _mealId),
        api,
      );
      final weight = find.widgetWithText(TextFormField, '实际食用量 (g)，未知可留空');
      await _reveal(tester, weight);
      await tester.enterText(weight, '120');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('保存修正'));
      expect(find.text('120'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'native home narrow large text: independent failed queries retry and retain unknown nutrition',
    (tester) async {
      final api = _LayoutApi()
        ..summaryFails = true
        ..mealsFail = true;
      await _pump(tester, const NativeHomeScreen(), api);
      final summaryRetry = find.text('今日营养加载失败，点击重试');
      await _reveal(tester, summaryRetry);
      api.summaryFails = false;
      await tester.tap(summaryRetry);
      await tester.pumpAndSettle();
      expect(api.summaryReads, 2);
      expect(api.mealReads, 1);
      expect(find.text('营养目标：未设置'), findsOneWidget);
      expect(find.text('— kcal'), findsOneWidget);
      final mealsRetry = find.text('今日餐食加载失败，点击重试');
      await _reveal(tester, mealsRetry);
      api.mealsFail = false;
      await tester.tap(mealsRetry);
      await tester.pumpAndSettle();
      expect(api.mealReads, 2);
      expect(api.summaryReads, 2);
      await _reveal(tester, find.text('真实记录保留较长的菜名与备注用于窄屏回归'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
