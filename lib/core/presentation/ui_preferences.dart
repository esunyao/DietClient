import 'package:diet_ui/diet_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
export 'package:diet_ui/diet_ui.dart' show GlassMode;

class UiPreferences {
  const UiPreferences({
    this.reduceTransparency = false,
    this.reduceMotion = false,
    this.glassMode = GlassMode.standard,
  });
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

class UiPreferencesController extends Notifier<UiPreferences> {
  @override
  UiPreferences build() => const UiPreferences();
  void setReduceTransparency(bool value) =>
      state = state.copyWith(reduceTransparency: value);
  void setReduceMotion(bool value) =>
      state = state.copyWith(reduceMotion: value);
  void setGlassMode(GlassMode value) =>
      state = state.copyWith(glassMode: value);
  void reset() => state = const UiPreferences();
}

final uiPreferencesProvider =
    NotifierProvider<UiPreferencesController, UiPreferences>(
      UiPreferencesController.new,
    );
