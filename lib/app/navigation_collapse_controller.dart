import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 仅消费主体的用户纵向滚动，动画和业务页面互相独立。
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
