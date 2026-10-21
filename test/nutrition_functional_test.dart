import 'package:diet_client/core/nutrition/application/analysis_polling.dart';
import 'package:diet_client/core/nutrition/data/nutri_models.dart';
import 'package:diet_client/features/trend/presentation/screens/native_trends_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'polling shares one clock, pauses invisible/background leases and stops at two minutes',
    (tester) async {
      var refreshes = 0, timeouts = 0;
      final poll = AnalysisPolling(() => refreshes++);
      addTearDown(poll.dispose);
      void update(String key, bool active, {bool pending = true}) =>
          poll.update(
            key,
            pending: pending,
            active: active,
            timeout: () => timeouts++,
          );
      update('one', true);
      update('two', true);
      await tester.pump(const Duration(seconds: 3));
      expect(refreshes, 1);
      update('one', false);
      update('two', false);
      await tester.pump(const Duration(seconds: 30));
      expect(refreshes, 1);
      update('one', true);
      await tester.pump(const Duration(seconds: 117));
      expect(refreshes, 40);
      expect(timeouts, 1);
      expect(poll.expired('one'), isTrue);
      await tester.pump(const Duration(minutes: 1));
      expect(refreshes, 40);
      poll.restart('one');
      await tester.pump(const Duration(seconds: 3));
      expect(refreshes, 41);
      update('one', true, pending: false);
      await tester.pump(const Duration(seconds: 10));
      expect(refreshes, 41);
    },
  );
  testWidgets('same query key is refreshed once per clock tick', (
    tester,
  ) async {
    var calls = 0;
    final poll = AnalysisPolling(
      () => throw StateError('unexpected default refresh'),
    );
    addTearDown(poll.dispose);
    for (final key in ['one', 'two']) {
      poll.update(
        key,
        pending: true,
        active: true,
        group: 'same-query',
        onRefresh: () => calls++,
        timeout: () {},
      );
    }
    await tester.pump(const Duration(seconds: 3));
    expect(calls, 1);
    poll.remove('one');
    poll.remove('two');
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 1);
  });
  testWidgets('changing query starts an independent visible polling window', (
    tester,
  ) async {
    var calls = 0;
    late StateSetter update;
    var query = 'first';
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return NutritionPolling(
                refreshKey: query,
                pending: true,
                onRefresh: () => calls++,
                child: const Text('pending'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(minutes: 2));
    await tester.pump();
    expect(calls, 40);
    expect(find.text('分析仍未结束，点击手动刷新'), findsOneWidget);
    update(() => query = 'second');
    await tester.pump();
    await tester.pump();
    expect(find.text('分析仍未结束，点击手动刷新'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 3));
    expect(calls, 40);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 3));
    expect(calls, 41);
    await tester.pump(const Duration(seconds: 117));
    await tester.pump();
    expect(calls, 80);
    expect(find.text('分析仍未结束，点击手动刷新'), findsOneWidget);
    await tester.pump(const Duration(minutes: 1));
    expect(calls, 80);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'widget lease pauses in app background and cancels when disposed',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: NutritionPolling(
              pending: true,
              onRefresh: () => calls++,
              child: const Text('pending'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(calls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 3));
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 2);
    },
  );
  test(
    'missing metric differs from a recorded zero; no meal day remains unknown',
    () {
      DailySummary day(int count, List<Map<String, Object>> nutrients) =>
          DailySummary.fromJson({
            'localDate': '2026-10-21',
            'mealCount': count,
            'nutrients': nutrients,
            'mealBreakdown': [],
            'updatedAt': '2026-10-21T00:00:00Z',
          });
      const zero = {
        'nutrientCode': 'PROTEIN',
        'nutrientName': '蛋白质',
        'unit': 'g',
        'amount': 0,
      };
      expect(recordedNutrient(day(1, []), 'PROTEIN'), isNull);
      expect(recordedNutrient(day(0, [zero]), 'PROTEIN'), isNull);
      expect(recordedNutrient(day(1, [zero]), 'PROTEIN'), 0);
      expect(recordedNutrient(null, 'PROTEIN'), isNull);
    },
  );
}
