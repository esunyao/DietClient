import 'dart:async';
import 'dart:convert';

import 'package:diet_client/core/config/ui_preview_config.dart';
import 'package:diet_client/core/presentation/ui_preferences.dart';
import 'package:diet_client/core/session/session_controller.dart';
import 'package:diet_client/demo/demo_store.dart';
import 'package:diet_client/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class PreferenceStorage implements UiPreferenceStorage {
  String? value;
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;
  int reads = 0;
  Completer<String?>? pendingRead;
  @override
  Future<String?> read() async {
    reads++;
    if (pendingRead != null) return pendingRead!.future;
    if (failRead) throw StateError('read failed');
    return value;
  }

  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('write failed');
    writes++;
    this.value = value;
  }
}

ProviderContainer containerFor(
  PreferenceStorage storage, {
  bool persist = true,
}) => ProviderContainer(
  overrides: [
    persistentUiPreferencesProvider.overrideWithValue(persist),
    uiPreferenceStorageProvider.overrideWithValue(storage),
  ],
);
Future<void> hydrate(ProviderContainer container) async {
  container.read(uiPreferencesProvider);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test(
    'overlapping reload is ignored so it cannot overwrite a later save',
    () async {
      final storage = PreferenceStorage()..pendingRead = Completer<String?>();
      final container = containerFor(storage);
      addTearDown(container.dispose);
      container.read(uiPreferencesProvider);
      await Future<void>.delayed(Duration.zero);
      await container.read(uiPreferencesProvider.notifier).reload();
      expect(storage.reads, 1);
      storage.pendingRead!.complete(null);
      await Future<void>.delayed(Duration.zero);
      await container
          .read(uiPreferencesProvider.notifier)
          .setReduceMotion(true);
      expect(container.read(uiPreferencesProvider).reduceMotion, isTrue);
    },
  );
  test(
    'appearance survives a new container without persisting any other state',
    () async {
      final storage = PreferenceStorage();
      final first = containerFor(storage);
      await hydrate(first);
      final controller = first.read(uiPreferencesProvider.notifier);
      await controller.setGlassMode(GlassMode.enhanced);
      await controller.setReduceMotion(true);
      await controller.setReduceTransparency(true);
      first.dispose();
      final second = containerFor(storage);
      addTearDown(second.dispose);
      await hydrate(second);
      final state = second.read(uiPreferencesProvider);
      expect(state.glassMode, GlassMode.enhanced);
      expect(state.reduceMotion, isTrue);
      expect(state.reduceTransparency, isTrue);
      expect((jsonDecode(storage.value!) as Map).keys.toSet(), {
        'glassMode',
        'reduceMotion',
        'reduceTransparency',
      });
    },
  );
  test(
    'unknown enum, wrong types and corrupted JSON fall back to defaults',
    () async {
      for (final raw in [
        '{"glassMode":"future","reduceMotion":"true","reduceTransparency":42}',
        '{',
        '[]',
      ]) {
        final storage = PreferenceStorage()..value = raw;
        final container = containerFor(storage);
        await hydrate(container);
        final state = container.read(uiPreferencesProvider);
        expect(state.glassMode, GlassMode.standard);
        expect(state.reduceMotion, isFalse);
        expect(state.reduceTransparency, isFalse);
        container.dispose();
      }
    },
  );
  test(
    'read and write failure visible, prior values restored, user can retry',
    () async {
      final storage = PreferenceStorage()..failRead = true;
      final container = containerFor(storage);
      addTearDown(container.dispose);
      await hydrate(container);
      expect(container.read(uiPreferencesProvider).error, isNotNull);
      storage.failRead = false;
      await container.read(uiPreferencesProvider.notifier).reload();
      storage.failWrite = true;
      await container
          .read(uiPreferencesProvider.notifier)
          .setGlassMode(GlassMode.enhanced);
      expect(
        container.read(uiPreferencesProvider).glassMode,
        GlassMode.standard,
      );
      expect(container.read(uiPreferencesProvider).error, contains('保存失败'));
      storage.failWrite = false;
      await container
          .read(uiPreferencesProvider.notifier)
          .setGlassMode(GlassMode.enhanced);
      expect(
        container.read(uiPreferencesProvider).glassMode,
        GlassMode.enhanced,
      );
      expect(container.read(uiPreferencesProvider).error, isNull);
    },
  );
  test('Web/other platforms retain memory-only preferences', () async {
    final storage = PreferenceStorage()
      ..failRead = true
      ..failWrite = true;
    final container = containerFor(storage, persist: false);
    addTearDown(container.dispose);
    await container.read(uiPreferencesProvider.notifier).setReduceMotion(true);
    expect(container.read(uiPreferencesProvider).reduceMotion, isTrue);
    expect(container.read(uiPreferencesProvider).error, isNull);
    expect(storage.writes, 0);
  });
  testWidgets(
    'native reset only changes appearance; demo data, consent, session untouched',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = PreferenceStorage()
        ..value = '{"glassMode":"enhanced","reduceMotion":true}';
      final container = ProviderContainer(
        overrides: [
          persistentUiPreferencesProvider.overrideWithValue(true),
          uiPreferenceStorageProvider.overrideWithValue(storage),
          nativeNutritionEnabledProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      container.read(uiPreferencesProvider);
      await tester.pump();
      final demoBefore = container.read(demoProvider);
      final epoch = container.read(sessionEpochProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('恢复默认外观'));
      await tester.tap(find.text('恢复默认外观'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('恢复'));
      await tester.pumpAndSettle();
      expect(
        container.read(uiPreferencesProvider).glassMode,
        GlassMode.standard,
      );
      expect(container.read(uiPreferencesProvider).reduceMotion, isFalse);
      expect(identical(container.read(demoProvider), demoBefore), isTrue);
      expect(container.read(sessionEpochProvider), epoch);
    },
  );
}
