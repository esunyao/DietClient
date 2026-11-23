import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// @brief 导航栏收起进度控制器，仅消费主体的用户纵向滚动。
/// @details 动画状态与业务页面相互独立。
class NavigationCollapseController extends ValueNotifier<double> {
  NavigationCollapseController() : super(0);
  bool interacting = false;
  bool _userScroll = false;
  double _down = 0;
  double _up = 0;

  void restore() {
    _down = _up = 0;
    value = 0;
  }

  /// @brief 根据主体用户滚动更新导航栏收起进度。
  /// @param notification 滚动通知对象。
  /// @return 始终返回 false，使滚动通知继续向上传播。
  bool handle(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      _userScroll = notification.dragDetails != null;
    }
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _userScroll = true;
    }
    // 导航交互或越界时不累计；回顶、反向累计 12 后恢复。
    // 向下累计 24 时进度到 1，继续至累计 120 时到 2。
    if (notification is ScrollUpdateNotification &&
        _userScroll &&
        !interacting &&
        !notification.metrics.outOfRange) {
      final delta = notification.scrollDelta ?? 0;
      if (notification.metrics.pixels <= notification.metrics.minScrollExtent) {
        restore();
      } else if (delta > 0) {
        _up = 0;
        _down += delta;
        if (_down >= 24) value = (1 + (_down - 24) / 96).clamp(0, 2);
      } else if (delta < 0) {
        _up -= delta;
        if (_up >= 12) restore();
      }
    }
    if (notification is ScrollEndNotification) _userScroll = false;
    return false;
  }
}
