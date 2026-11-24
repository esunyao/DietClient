import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
export 'package:diet_ui/diet_ui.dart' show GlassMode;

/// 饮食历史列表的展示布局模式。
enum MealHistoryLayout { compact, photoCard }

/// 外观偏好选择及其读写状态模型。
class UiPreferences {
  const UiPreferences({
    this.loading = false,
    this.saving = false,
    this.error,
    this.reduceTransparency = false,
    this.reduceMotion = false,
    this.glassMode = GlassMode.standard,
    this.mealHistoryLayout = MealHistoryLayout.compact,
  });
  final bool loading;
  final bool saving;
  final String? error;
  final bool reduceTransparency;
  final bool reduceMotion;
  final GlassMode glassMode;
  final MealHistoryLayout mealHistoryLayout;

  /// 是否正在读取或保存本机偏好。
  bool get isBusy => loading || saving;

  /// 复制更新后的外观选择项并重置加载、保存与错误标记。
  UiPreferences copyWith({
    bool? reduceTransparency,
    bool? reduceMotion,
    GlassMode? glassMode,
    MealHistoryLayout? mealHistoryLayout,
  }) => UiPreferences(
    reduceTransparency: reduceTransparency ?? this.reduceTransparency,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    glassMode: glassMode ?? this.glassMode,
    mealHistoryLayout: mealHistoryLayout ?? this.mealHistoryLayout,
  );
}

/// 外观偏好 JSON 的异步存储边界接口（不用于保存会话或健康资料）。
abstract interface class UiPreferenceStorage {
  Future<String?> read();
  Future<void> write(String value);
}

/// 基于 `SharedPreferencesAsync` 的本机外观偏好存储实现。
class SharedUiPreferenceStorage implements UiPreferenceStorage {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  static const key = 'diet.appearance.v1';
  @override
  Future<String?> read() => _preferences.getString(key);
  @override
  Future<void> write(String value) => _preferences.setString(key, value);
}

/// 当前平台是否启用本机持久化外观偏好（仅 Android 与 Windows 非 Web 端）。
final persistentUiPreferencesProvider = Provider<bool>(
  (ref) =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.windows),
);

/// 外观偏好存储适配器 Provider。
final uiPreferenceStorageProvider = Provider<UiPreferenceStorage>(
  (ref) => SharedUiPreferenceStorage(),
);

/// 外观偏好状态控制器；持久化平台初始化时异步读取本机设置。
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
    mealHistoryLayout: value.mealHistoryLayout,
    reduceTransparency: value.reduceTransparency,
    reduceMotion: value.reduceMotion,
    loading: loading,
    saving: saving,
    error: error,
  );

  /// 重新读取本机持久化的外观偏好；读写进行中不重复加载。
  Future<void> reload() async {
    if (!ref.mounted || _loading || state.saving) return;
    if (!ref.read(persistentUiPreferencesProvider)) return;
    _loading = true;
    state = _status(state, loading: true);
    try {
      final raw = await ref.read(uiPreferenceStorageProvider).read();
      var prefs = const UiPreferences();
      // 未知枚举值及格式无效的数据回退默认项，以兼容本地旧值。
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
              mealHistoryLayout:
                  MealHistoryLayout.values
                      .where(
                        (layout) => layout.name == json['mealHistoryLayout'],
                      )
                      .firstOrNull ??
                  MealHistoryLayout.compact,
              reduceTransparency: json['reduceTransparency'] == true,
              reduceMotion: json['reduceMotion'] == true,
            );
          }
        } on FormatException {
          // 无效的本机外观记录回退到默认配置。
        }
      }
      if (ref.mounted) state = prefs;
    } catch (_) {
      if (ref.mounted) state = _status(state, error: '无法读取外观设置，可重试；当前保留可用外观。');
    } finally {
      _loading = false;
    }
  }

  /// 保存新外观偏好并在持久化成功后更新状态；失败时恢复此前选择。
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
              'mealHistoryLayout': next.mealHistoryLayout.name,
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
  Future<void> setMealHistoryLayout(MealHistoryLayout value) =>
      _save(state.copyWith(mealHistoryLayout: value));
  Future<void> reset() => _save(const UiPreferences());
}

final uiPreferencesProvider =
    NotifierProvider<UiPreferencesController, UiPreferences>(
      UiPreferencesController.new,
    );
