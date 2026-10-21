import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:diet_auth/diet_auth.dart';
import 'package:diet_client/core/config/api_config.dart';
import 'package:diet_client/core/config/ui_preview_config.dart';
import 'package:diet_client/core/network/api_client.dart';
import 'package:diet_client/core/nutrition/application/nutrition_providers.dart';
import 'package:diet_client/features/meal/application/meal_edit.dart';
import 'package:diet_client/features/meal/presentation/screens/meal_correction_screen.dart';
import 'package:diet_client/features/meal/presentation/screens/meal_detail_screen.dart';
import 'package:diet_client/features/meal/presentation/screens/meal_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Map<String, dynamic> mealJson() => {
  'mealId': '9007199254740993',
  'captureSessionId': '00000000-0000-4000-8000-000000000001',
  'mealType': 'lunch',
  'consumedAt': '2026-10-20T12:00:00+08:00',
  'localDate': '2026-10-20',
  'timezone': 'Asia/Shanghai',
  'notes': '原备注',
  'analysisStatus': 'completed',
  'createdAt': '2026-10-20T04:00:00Z',
  'updatedAt': '2026-10-20T04:00:00Z',
  'nutrients': [
    {
      'nutrientCode': 'ENERGY_KCAL',
      'nutrientName': '能量',
      'unit': 'kcal',
      'amount': 100,
    },
  ],
  'items': [
    {
      'itemId': '9007199254740994',
      'sequenceNo': 1,
      'displayName': '鱼',
      'estimatedWeightG': 150,
      'confidence': .8,
      'dataSource': 'ai',
      'userCorrected': false,
      'notes': '熟重',
      'nutrients': [
        {
          'nutrientCode': 'ENERGY_KCAL',
          'nutrientName': '能量',
          'unit': 'kcal',
          'amount': 100,
        },
        {
          'nutrientCode': 'IRON',
          'nutrientName': '铁',
          'unit': 'mg',
          'amount': 2.5,
        },
      ],
    },
  ],
};

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final FutureOr<ResponseBody> Function(RequestOptions) handler;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _response(Object? data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode({'code': 200, 'data': data}),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
NutriApi _api(_Adapter adapter) => NutriApi(
  ApiClient(
    config: ApiConfig('https://api.test/'),
    session: OidcSession(
      accessToken: 'test',
      tokenType: 'Bearer',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ),
    isCurrent: () => true,
    onUnauthorized: () {},
    dio: Dio()..httpClientAdapter = adapter,
  ),
);
Future<void> _pump(
  WidgetTester tester,
  Widget page,
  NutriApi api, {
  bool native = true,
}) async {
  final router = GoRouter(
    initialLocation: '/screen',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('已返回')),
        routes: [GoRoute(path: 'screen', builder: (_, _) => page)],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nutritionApiProvider.overrideWithValue(api),
        nativeNutritionEnabledProvider.overrideWithValue(native),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('item correction preserves IDs, unknown codes and values without scaling by weight', () {
    final original = Meal.fromJson(mealJson());
    final draft = MealItemEdit(original: original.items.single)..weight = '120';
    final payload = draft.toInput().toJson();
    expect(payload['itemId'], '9007199254740994');
    expect(payload['estimatedWeightG'], 120);
    expect(payload['notes'], '熟重');
    expect(payload['nutrients'], [
      {'nutrientCode': 'ENERGY_KCAL', 'amount': 100.0},
      {'nutrientCode': 'IRON', 'amount': 2.5},
    ]);
    draft.weight = '0';
    expect(draft.toInput, throwsFormatException);
    draft.weight = '100001';
    expect(draft.toInput, throwsFormatException);
    draft.weight = '';
    draft.amounts.clear();
    expect(draft.toInput, throwsFormatException);
  });
  testWidgets(
    'metadata failure keeps input; retry sends original timezone and explicit notes then returns',
    (tester) async {
      var fail = true;
      final adapter = _Adapter((r) {
        if (r.method == 'PATCH' && fail) return _response(null, status: 500);
        return _response(mealJson());
      });
      final api = _api(adapter);
      addTearDown(api.close);
      await _pump(
        tester,
        const MealCorrectionScreen(mealId: '9007199254740993'),
        api,
      );
      final notes = find.widgetWithText(TextField, '本餐备注');
      await tester.enterText(notes, '修改后的备注');
      await tester.tap(find.text('保存修正'));
      await tester.pumpAndSettle();
      expect(find.text('修改后的备注'), findsOneWidget);
      expect(adapter.requests.where((r) => r.method == 'PATCH'), hasLength(1));
      fail = false;
      await tester.tap(find.text('保存修正'));
      await tester.pumpAndSettle();
      final patches = adapter.requests
          .where((r) => r.method == 'PATCH')
          .toList();
      expect(patches, hasLength(2));
      expect(patches.last.data, containsPair('notes', '修改后的备注'));
      expect(patches.last.data, containsPair('timezone', 'Asia/Shanghai'));
      expect(find.text('已返回'), findsOneWidget);
    },
  );
  testWidgets('full item replacement keeps unedited nutrients and server IDs', (
    tester,
  ) async {
    final adapter = _Adapter((_) => _response(mealJson()));
    final api = _api(adapter);
    addTearDown(api.close);
    await _pump(
      tester,
      const MealCorrectionScreen(mealId: '9007199254740993'),
      api,
    );
    final weight = find.widgetWithText(TextFormField, '实际食用量 (g)，未知可留空');
    await tester.ensureVisible(weight);
    await tester.enterText(weight, '120');
    await tester.tap(find.text('保存修正'));
    await tester.pumpAndSettle();
    final put = adapter.requests.singleWhere((r) => r.method == 'PUT');
    final data = put.data as Map;
    expect(data['timezone'], 'Asia/Shanghai');
    expect(data['notes'], '原备注');
    final item = (data['items'] as List).single as Map;
    expect(item['itemId'], '9007199254740994');
    expect(item['estimatedWeightG'], 120);
    expect(
      item['nutrients'],
      equals([
        {'nutrientCode': 'ENERGY_KCAL', 'amount': 100.0},
        {'nutrientCode': 'IRON', 'amount': 2.5},
      ]),
    );
  });
  testWidgets('delete requires confirmation; cancel causes no write', (
    tester,
  ) async {
    final adapter = _Adapter(
      (r) => _response(r.method == 'DELETE' ? null : mealJson()),
    );
    final api = _api(adapter);
    addTearDown(api.close);
    await _pump(
      tester,
      const MealDetailScreen(mealId: '9007199254740993'),
      api,
    );
    await tester.ensureVisible(find.text('删除记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(adapter.requests.where((r) => r.method == 'DELETE'), isEmpty);
    await tester.tap(find.text('删除记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(adapter.requests.where((r) => r.method == 'DELETE'), hasLength(1));
    expect(find.text('已返回'), findsOneWidget);
  });
  testWidgets('history sends required dates, keyword and server pagination', (
    tester,
  ) async {
    final adapter = _Adapter(
      (r) => _response({
        'items': [],
        'page': r.queryParameters['page'],
        'pageSize': 20,
        'total': 42,
      }),
    );
    final api = _api(adapter);
    addTearDown(api.close);
    await _pump(tester, const MealHistoryScreen(), api);
    expect(adapter.requests.single.queryParameters['dateFrom'], isNotNull);
    expect(adapter.requests.single.queryParameters['dateTo'], isNotNull);
    await tester.enterText(find.byType(TextField), '鱼');
    await tester.tap(find.text('应用筛选'));
    await tester.pumpAndSettle();
    expect(adapter.requests.last.queryParameters['q'], '鱼');
    await tester.ensureVisible(find.text('下一页'));
    await tester.tap(find.text('下一页'));
    await tester.pumpAndSettle();
    expect(adapter.requests.last.queryParameters['page'], 2);
  });
  testWidgets(
    'native manual create is unsupported and demo branch sends no added calls',
    (tester) async {
      final adapter = _Adapter((_) => throw StateError('unexpected request'));
      final api = _api(adapter);
      addTearDown(api.close);
      await _pump(tester, const MealCorrectionScreen(), api);
      expect(find.textContaining('独立手工新建暂未支持'), findsOneWidget);
      expect(find.textContaining('设计样例'), findsNothing);
      expect(adapter.requests, isEmpty);
      await _pump(tester, const MealHistoryScreen(), api, native: false);
      expect(adapter.requests, isEmpty);
    },
  );
}
