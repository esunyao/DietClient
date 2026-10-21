import 'dart:ui';

import 'package:diet_client/app/app_shell.dart';
import 'package:diet_client/core/presentation/ui_preferences.dart';
import 'package:diet_client/core/presentation/account_identity.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = [
  AppNavigationDestination(label: '首页', icon: Icons.home),
  AppNavigationDestination(label: '配餐', icon: Icons.restaurant),
  AppNavigationDestination(label: '趋势', icon: Icons.timeline),
  AppNavigationDestination(label: '我的', icon: Icons.person),
];

Widget _sidebar({
  bool menuOpen = false,
  bool reduced = false,
  double textScale = 1,
  double height = 580,
}) => MaterialApp(
  theme: AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduced,
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: height,
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
  testWidgets('真实账户区中间帧连续且菜单在移出后保持展开', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const name = '测试账户';
    final container = ProviderContainer(
      overrides: [
        accountIdentityProvider.overrideWith(
          (_) async => const AccountIdentity(name: name),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(uiPreferencesProvider.notifier).setGlassMode(GlassMode.off);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AppShell(location: '/home', child: SizedBox()),
        ),
      ),
    );
    await tester.pump();
    final avatar = find.descendant(
      of: find.byType(AppSideNavigation),
      matching: find.byType(AccountAvatar),
    );
    final account = find.byTooltip('个人菜单');
    final accountElement = tester.element(account);
    final avatarElement = tester.element(avatar);
    expect(find.text(name), findsOneWidget);
    final labelWidth = tester.getSize(find.text(name)).width;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(500, 100));
    await mouse.moveTo(const Offset(40, 100));
    await tester.pump(const Duration(milliseconds: 120));
    var previous = tester.getCenter(avatar);
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final center = tester.getCenter(avatar);
      expect((center - previous).distance, lessThan(8));
      expect(tester.element(account), same(accountElement));
      expect(tester.element(avatar), same(avatarElement));
      expect(tester.getSize(find.text(name)).width, labelWidth);
      expect(tester.takeException(), isNull);
      previous = center;
    }
    await tester.tap(account);
    await tester.pumpAndSettle();
    expect(find.text('应用设置'), findsOneWidget);
    await mouse.moveTo(const Offset(500, 100));
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump(const Duration(milliseconds: 240));
    expect(_width(tester), 216);
    expect(tester.element(account), same(accountElement));
    await tester.tapAt(const Offset(600, 300));
    await tester.pumpAndSettle();
    expect(_width(tester), 96);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('真实账户区长名称与大字短窗口保持可达', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 420);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const name = '用于验证侧栏连续动画的长账户名称';
    final container = ProviderContainer(
      overrides: [
        accountIdentityProvider.overrideWith(
          (_) async => const AccountIdentity(name: name),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(uiPreferencesProvider.notifier).setGlassMode(GlassMode.off);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const AppShell(location: '/home', child: SizedBox()),
          ),
        ),
      ),
    );
    await tester.pump();
    final scroll = find.descendant(
      of: find.byType(AppSideNavigation),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byTooltip('个人菜单'),
      100,
      scrollable: scroll,
    );
    final account = find.byTooltip('个人菜单');
    await tester.tap(account);
    await tester.pump();
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
    expect(_width(tester), 216);
    expect(find.text('应用设置'), findsOneWidget);
    final label = tester.widget<Text>(find.text(name));
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
    expect(tester.getSize(find.text(name)).height, greaterThanOrEqualTo(42));
    await tester.tapAt(const Offset(600, 200));
    await tester.pumpAndSettle();
    expect(account.hitTestable(), findsOneWidget);
    expect(find.text('设置').first.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('单份图标和稳定文字槽位在中间帧连续移动', (tester) async {
    await tester.pumpWidget(_sidebar());
    final icon = find.byIcon(Icons.home);
    expect(icon, findsOneWidget);
    final compactCenter = tester.getCenter(icon);
    final compactHeight = tester
        .getSize(find.widgetWithText(TextButton, '首页').first)
        .height;
    await tester.pumpWidget(_sidebar(menuOpen: true));
    var previous = compactCenter;
    double? labelWidth;
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(icon, findsOneWidget);
      final center = tester.getCenter(icon);
      expect(center.dx, lessThanOrEqualTo(previous.dx));
      expect((center - previous).distance, lessThan(8));
      expect(
        tester.getSize(find.widgetWithText(TextButton, '首页').first).height,
        compactHeight,
      );
      final label = find.text('首页').last;
      final width = tester.getSize(label).width;
      labelWidth ??= width;
      expect(width, labelWidth);
      expect(tester.takeException(), isNull);
      previous = center;
    }
    expect(_width(tester), 216);
    expect(previous.dx, lessThan(compactCenter.dx));
    await tester.pumpWidget(_sidebar());
    for (var i = 0; i < 13; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final center = tester.getCenter(icon);
      expect(center.dx, greaterThanOrEqualTo(previous.dx));
      expect((center - previous).distance, lessThan(10));
      previous = center;
      expect(tester.takeException(), isNull);
    }
    expect(tester.getCenter(icon), compactCenter);
  });

  testWidgets('中间帧保持单份语义且大字短视口无溢出', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_sidebar(textScale: 2, height: 260));
    expect(find.bySemanticsLabel('首页'), findsOneWidget);
    await tester.pumpWidget(
      _sidebar(menuOpen: true, textScale: 2, height: 260),
    );
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.bySemanticsLabel('首页'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    final scroll = find.descendant(
      of: find.byType(AppSideNavigation),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(find.text('账户'), 100, scrollable: scroll);
    expect(find.text('账户').hitTestable(), findsOneWidget);
    expect(find.text('设置').last.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

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
