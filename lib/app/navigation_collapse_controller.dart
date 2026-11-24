import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 导航栏收起进度控制器，仅响应页面主体的用户纵向滚动。
class NavigationCollapseController extends ValueNotifier<double> {
  NavigationCollapseController() : super(0);
  bool interacting = false;
  bool _userScroll = false;
  double _down = 0;
  double _up = 0;

  /// 恢复导航栏至完整展开态。
  void restore() {
    _down = _up = 0;
    value = 0;
  }

  /// 处理页面主体滚动通知并更新收起进度；始终返回 `false` 以便继续冒泡。
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
