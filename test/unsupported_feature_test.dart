import 'package:diet_client/core/config/ui_preview_config.dart';
import 'package:diet_client/demo/demo_store.dart';
import 'package:diet_client/features/institution/presentation/screens/institution_menu_screen.dart';
import 'package:diet_client/features/institution/presentation/screens/institution_sync_screen.dart';
import 'package:diet_client/features/meal_plan/presentation/screens/meal_plan_screen.dart';
import 'package:diet_client/features/report/presentation/screens/reports_screen.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('真实模式未支持页面不展示样例或提供模拟写入', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [nativeNutritionEnabledProvider.overrideWithValue(true)],
    );
    addTearDown(container.dispose);
    final before = container.read(demoProvider);
    for (final page in const [
      MealPlanScreen(),
      ReportsScreen(),
      InstitutionMenuScreen(),
      InstitutionSyncScreen(),
    ]) {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: page),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('暂未支持'), findsOneWidget);
      expect(find.text('设计样例 · 演示数据'), findsNothing);
      expect(find.text('生成新报告（演示）'), findsNothing);
      expect(find.text('加入晚餐计划'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(identical(container.read(demoProvider), before), isTrue);
    }
  });
}
