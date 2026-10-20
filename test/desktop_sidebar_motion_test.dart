import 'dart:ui';

import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = [
  AppNavigationDestination(label: '首页', icon: Icons.home),
  AppNavigationDestination(label: '配餐', icon: Icons.restaurant),
  AppNavigationDestination(label: '趋势', icon: Icons.timeline),
  AppNavigationDestination(label: '我的', icon: Icons.person),
];

Widget _sidebar({bool menuOpen = false, bool reduced = false}) => MaterialApp(
  theme: AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: 580,
          child: AppSideNavigation(
            destinations: _items,
            selectedIndex: 0,
            onSelected: (_) {},
            onSettings: () {},
            accountBuilder: (_) => const Text('账户'),
            menuOpen: menuOpen,
            glassMode: GlassMode.off,
          ),
        ),
      ),
    ),
  ),
);

double _width(WidgetTester tester) =>
    tester.getSize(find.byType(AppSideNavigation)).width;

void main() {
  testWidgets('重复展开事件不重启已有运动', (tester) async {
    await tester.pumpWidget(_sidebar());
    await tester.pumpWidget(_sidebar(menuOpen: true));
    await tester.pump(const Duration(milliseconds: 60));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(500, 100));
    await mouse.moveTo(const Offset(40, 100));
    await tester.pump(const Duration(milliseconds: 120));
    final before = _width(tester);
    await tester.pump(const Duration(milliseconds: 60));
    expect(_width(tester), 216);
    expect(_width(tester), greaterThan(before));
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('部分展开反向按剩余进度收起且不跳位', (tester) async {
    await tester.pumpWidget(_sidebar());
    await tester.pumpWidget(_sidebar(menuOpen: true));
    await tester.pump(const Duration(milliseconds: 60));
    final before = _width(tester);
    expect(before, greaterThan(96));
    await tester.pumpWidget(_sidebar());
    expect(_width(tester), closeTo(before, .001));
    await tester.pump(const Duration(milliseconds: 25));
    expect(_width(tester), lessThan(before));
    await tester.pump(const Duration(milliseconds: 25));
    expect(_width(tester), 96);
    await tester.pumpAndSettle();
    expect(_width(tester), 96);
  });

  testWidgets('运动途中启用减少动态立即完成并停止 ticker', (tester) async {
    await tester.pumpWidget(_sidebar());
    await tester.pumpWidget(_sidebar(menuOpen: true));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_width(tester), inExclusiveRange(96, 216));
    await tester.pumpWidget(_sidebar(menuOpen: true, reduced: true));
    expect(_width(tester), 216);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(_sidebar(reduced: true));
    expect(_width(tester), 96);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
