import 'package:diet_models/diet_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 真实界面的临时显示状态，仅保存体验模式与隐私隐藏选择，不持有业务样例或机构授权。
class DisplayState {
  const DisplayState({
    this.mode = ExperienceMode.personal,
    this.privacyHidden = false,
  });
  final ExperienceMode mode;
  final bool privacyHidden;
  bool get isInstitution => mode == ExperienceMode.institution;
}

/// 真实体验模式与隐私遮罩控制器。
class DisplayController extends Notifier<DisplayState> {
  @override
  DisplayState build() => const DisplayState();

  /// 切换体验模式并重置隐私遮罩为关闭状态。
  void selectMode(ExperienceMode mode) => state = DisplayState(mode: mode);

  /// 在保留当前体验模式的前提下更新隐私遮罩开关。
  void setPrivacyHidden(bool hidden) =>
      state = DisplayState(mode: state.mode, privacyHidden: hidden);
}

final displayStateProvider = NotifierProvider<DisplayController, DisplayState>(
  DisplayController.new,
);
