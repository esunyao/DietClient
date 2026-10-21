import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
export 'package:diet_ui/diet_ui.dart' show GlassMode;

class UiPreferences {
  const UiPreferences({
    this.loading = false,
    this.saving = false,
    this.error,
    this.reduceTransparency = false,
    this.reduceMotion = false,
    this.glassMode = GlassMode.standard,
  });
  final bool loading;
  final bool saving;
  final String? error;
  final bool reduceTransparency;
  final bool reduceMotion;
  final GlassMode glassMode;
  UiPreferences copyWith({
    bool? reduceTransparency,
    bool? reduceMotion,
    GlassMode? glassMode,
  }) => UiPreferences(
    reduceTransparency: reduceTransparency ?? this.reduceTransparency,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    glassMode: glassMode ?? this.glassMode,
  );
}

abstract interface class UiPreferenceStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedUiPreferenceStorage implements UiPreferenceStorage {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  static const key = 'diet.appearance.v1';
  @override
  Future<String?> read() => _preferences.getString(key);
  @override
  Future<void> write(String value) => _preferences.setString(key, value);
}

final persistentUiPreferencesProvider = Provider<bool>(
  (ref) =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.windows),
);
final uiPreferenceStorageProvider = Provider<UiPreferenceStorage>(
  (ref) => SharedUiPreferenceStorage(),
);

class UiPreferencesController extends Notifier<UiPreferences> {
  bool _loading = false;
  @override
  UiPreferences build() {
    if (ref.watch(persistentUiPreferencesProvider)) {
      unawaited(Future.microtask(reload));
      return const UiPreferences(loading: true);
    }
    return const UiPreferences();
  }

  UiPreferences _status(
    UiPreferences value, {
    bool loading = false,
    bool saving = false,
    String? error,
  }) => UiPreferences(
    glassMode: value.glassMode,
    reduceTransparency: value.reduceTransparency,
    reduceMotion: value.reduceMotion,
    loading: loading,
    saving: saving,
    error: error,
  );
  Future<void> reload() async {
    if (!ref.mounted || _loading || state.saving) return;
    if (!ref.read(persistentUiPreferencesProvider)) return;
    _loading = true;
    state = _status(state, loading: true);
    try {
      final raw = await ref.read(uiPreferenceStorageProvider).read();
      var prefs = const UiPreferences();
      if (raw != null) {
        try {
          final json = jsonDecode(raw);
          if (json is Map) {
            prefs = UiPreferences(
              glassMode:
                  GlassMode.values
                      .where((m) => m.name == json['glassMode'])
                      .firstOrNull ??
                  GlassMode.standard,
              reduceTransparency: json['reduceTransparency'] == true,
              reduceMotion: json['reduceMotion'] == true,
            );
          }
        } on FormatException {
          /* Invalid local appearance falls back to defaults. */
        }
      }
      if (ref.mounted) state = prefs;
    } catch (_) {
      if (ref.mounted) state = _status(state, error: '无法读取外观设置，可重试；当前保留可用外观。');
    } finally {
      _loading = false;
    }
  }

  Future<void> _save(UiPreferences next) async {
    if (state.loading || state.saving) return;
    final previous = state;
    if (!ref.read(persistentUiPreferencesProvider)) {
      state = next;
      return;
    }
    state = _status(previous, saving: true);
    try {
      await ref
          .read(uiPreferenceStorageProvider)
          .write(
            jsonEncode({
              'glassMode': next.glassMode.name,
              'reduceTransparency': next.reduceTransparency,
              'reduceMotion': next.reduceMotion,
            }),
          );
      if (ref.mounted) state = next;
    } catch (_) {
      if (ref.mounted) {
        state = _status(previous, error: '外观设置保存失败，已恢复此前值。请重试该操作。');
      }
    }
  }

  Future<void> setReduceTransparency(bool value) =>
      _save(state.copyWith(reduceTransparency: value));
  Future<void> setReduceMotion(bool value) =>
      _save(state.copyWith(reduceMotion: value));
  Future<void> setGlassMode(GlassMode value) =>
      _save(state.copyWith(glassMode: value));
  Future<void> reset() => _save(const UiPreferences());
}

final uiPreferencesProvider =
    NotifierProvider<UiPreferencesController, UiPreferences>(
      UiPreferencesController.new,
    );
