import 'package:diet_client/core/config/ui_preview_config.dart';
import 'package:diet_client/demo/demo_store.dart';
import 'package:diet_client/features/meal/presentation/screens/meal_correction_screen.dart';
import 'package:diet_client/features/meal/presentation/screens/meal_history_screen.dart';
import 'package:diet_client/features/meal/presentation/screens/native_meal_correction_screen.dart';
import 'package:diet_client/features/meal/presentation/screens/native_meal_history_screen.dart';
import 'package:diet_client/features/meal_record/presentation/screens/native_recognition_screen.dart';
import 'package:diet_client/features/meal_record/presentation/screens/recognition_screen.dart';
import 'package:diet_client/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:diet_client/features/profile/presentation/screens/health_record_form_screen.dart';
import 'package:diet_client/features/profile/presentation/screens/real_edit_profile_screen.dart';
import 'package:diet_client/features/profile/presentation/screens/real_health_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ForbiddenDemoController extends DemoController {
  @override
  DemoSnapshot build() => throw StateError('Real entry initialized demo state');
}

void main() {
  final entries = <Widget, Type>{
    const MealHistoryScreen(): NativeMealHistoryScreen,
    const MealCorrectionScreen(mealId: '123'): NativeMealCorrectionScreen,
    const RecognitionScreen(): NativeRecognitionScreen,
    const EditProfileScreen(): RealEditProfileScreen,
    const HealthRecordFormScreen(kind: 'measurement'): RealHealthFormScreen,
  };
  for (final entry in entries.entries) {
    testWidgets(
      '${entry.key.runtimeType} mounts real page without demo state',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            uiPreviewProvider.overrideWithValue(false),
            nativeNutritionEnabledProvider.overrideWithValue(true),
            demoProvider.overrideWith(_ForbiddenDemoController.new),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(home: entry.key),
          ),
        );
        await tester.pump();
        expect(find.byType(entry.value), findsOneWidget);
        expect(container.exists(demoProvider), isFalse);
        expect(find.text('设计样例 · 演示数据'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
