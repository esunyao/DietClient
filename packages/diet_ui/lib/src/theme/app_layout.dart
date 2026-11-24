import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 逻辑尺寸与响应式断点常量；安全区由页面与导航各自覆盖区域处理。
abstract final class AppLayout {
  static const navigationBreakpoint = 840.0;
  static const maxPageWidth = 1194.0;
  static const mobileGutter = 24.0;
  static const wideGutter = 32.0;
  static const columnGap = 24.0;
  static const mainColumnWidth = 754.0;
  static const asideColumnWidth = 352.0;
  static const columnsMinWidth = 1024.0 - wideGutter * 2;
  static const sectionGap = 16.0;
  static const cardRadius = 20.0;
  static const listRadius = 16.0;
  static const controlRadius = 12.0;
  static const bottomNavigationHeight = 58.0;
  static const bottomNavigationRadius = 31.0;
  static const bottomNavigationMargin = 16.0;
  static const bottomNavigationMaxWidth = 340.0;
  static const topNavigationHeight = 84.0;

  /// 根据可用页面宽度返回左右内边距。
  static double pageGutter(double width) =>
      width >= navigationBreakpoint ? wideGutter : mobileGutter;

  /// 根据当前文字缩放比例计算宽屏顶部导航栏高度。
  static double topBarHeight(TextScaler textScaler) => math.max(
    topNavigationHeight,
    math.max(textScaler.scale(16) * 1.4 + 20, 44) + 40,
  );
}
