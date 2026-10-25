import 'package:diet_models/diet_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 真实界面的临时显示选择，不持有业务样例或机构授权。
class DisplayState {
  const DisplayState({
    this.mode = ExperienceMode.personal,
    this.privacyHidden = false,
  });
  final ExperienceMode mode;
  final bool privacyHidden;
  bool get isInstitution => mode == ExperienceMode.institution;
}

class DisplayController extends Notifier<DisplayState> {
  @override
  DisplayState build() => const DisplayState();

  void selectMode(ExperienceMode mode) => state = DisplayState(mode: mode);
  void setPrivacyHidden(bool hidden) =>
      state = DisplayState(mode: state.mode, privacyHidden: hidden);
}

final displayStateProvider = NotifierProvider<DisplayController, DisplayState>(
  DisplayController.new,
);
