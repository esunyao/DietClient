import 'package:diet_client/core/config/ui_preview_config.dart';
import 'package:diet_client/core/presentation/display_state.dart';
import 'package:diet_client/core/presentation/ui_preferences.dart';
import 'package:diet_client/demo/demo_store.dart';
import 'package:diet_client/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'real display mode and privacy leave demo business changes intact',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [
          uiPreviewProvider.overrideWithValue(false),
          nativeNutritionEnabledProvider.overrideWithValue(true),
          persistentUiPreferencesProvider.overrideWithValue(false),
        ],
      );
      container.read(demoProvider.notifier).setAiConsent(false);
      final demo = container.read(demoProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('机构内个人'));
      await tester.tap(find.text('机构内个人'));
      await tester.pumpAndSettle();
      expect(container.read(displayStateProvider).isInstitution, isTrue);
      expect(identical(container.read(demoProvider), demo), isTrue);
      await tester.ensureVisible(find.text('暂时隐藏个人信息'));
      await tester.tap(find.text('暂时隐藏个人信息'));
      await tester.pumpAndSettle();
      expect(container.read(displayStateProvider).privacyHidden, isTrue);
      expect(container.read(demoProvider).privacyHidden, isFalse);
      expect(find.text('设计样例 · 演示数据'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
}
