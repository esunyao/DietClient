import 'package:diet_models/diet_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// @brief 真实界面的临时显示状态。
/// @details 仅保存体验模式与隐私隐藏选择，不持有业务样例或机构授权。
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

  /// @brief 切换体验模式并重置隐私遮罩为默认状态。
  /// @param mode 目标体验模式。
  /// @note 仅切换遮罩状态时由 setPrivacyHidden 保留当前模式。
  void selectMode(ExperienceMode mode) => state = DisplayState(mode: mode);
  void setPrivacyHidden(bool hidden) =>
      state = DisplayState(mode: state.mode, privacyHidden: hidden);
}

final displayStateProvider = NotifierProvider<DisplayController, DisplayState>(
  DisplayController.new,
);
