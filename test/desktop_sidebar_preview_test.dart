import 'package:diet_client/app/app_shell.dart';
import 'package:diet_client/app/diet_app.dart';
import 'package:diet_client/app/router.dart';
import 'package:diet_client/core/config/ui_preview_config.dart';
import 'package:diet_client/core/presentation/ui_preferences.dart';
import 'package:diet_client/core/session/session_controller.dart';
import 'package:diet_client/demo/demo_store.dart';
import 'package:diet_client/features/auth/application/login_controller.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = [
  AppNavigationDestination(label: '首页', icon: Icons.home),
  AppNavigationDestination(label: '配餐', icon: Icons.restaurant),
  AppNavigationDestination(label: '趋势', icon: Icons.timeline),
  AppNavigationDestination(label: '我的', icon: Icons.person),
];

void main() {
  test('preview requires both Web and explicit flag; redirects preserve deep links', () {
    for (final web in [false, true]) {
      for (final enabled in [false, true]) {
        expect(isUiPreviewEnabled(web: web, enabled: enabled), web && enabled);
      }
    }
    for (final path in [
      '/login',
      '/register',
      '/verify-email',
      '/email-verified',
    ]) {
      expect(
        authenticationRedirect(path, authenticated: false, uiPreview: true),
        '/home',
      );
    }
    for (final path in [
      '/home',
      '/meals/sample/correction',
      '/profile/health-records/weight',
    ]) {
      expect(
        authenticationRedirect(path, authenticated: false, uiPreview: true),
        isNull,
      );
      expect(authenticationRedirect(path, authenticated: false), '/login');
    }
  });

  testWidgets(
    'preview starts at home, opens deep links and privacy without constructing auth',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          uiPreviewProvider.overrideWithValue(true),
          authGatewayProvider.overrideWith(
            (ref) => throw StateError('preview constructed auth'),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const DietApp()),
      );
      await tester.pumpAndSettle();
      final router = container.read(appRouterProvider);
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(find.text('Web UI 预览 · 未登录'), findsOneWidget);
      expect(container.read(sessionProvider), isNull);
      router.go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('退出当前应用'), findsNothing);
      router.go('/profile/health-records/weight');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/profile/health-records/weight',
      );
      router.go('/login');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      container
          .read(demoProvider.notifier)
          .selectMode(ExperienceMode.institution);
      container.read(demoProvider.notifier).setPrivacyHidden(true);
      await tester.pumpAndSettle();
      expect(find.text('个人信息已暂时隐藏'), findsOneWidget);
      await tester.tap(find.text('恢复演示预览'));
      await tester.pumpAndSettle();
      expect(container.read(demoProvider).privacyHidden, isFalse);
      expect(container.read(sessionProvider), isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets(
    'sidebar hover delays, reverse animation, focus and menu retain expansion',
    (tester) async {
      var selected = -1;
      Widget build({bool menu = false, bool reduced = false}) => MaterialApp(
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
                  onSelected: (i) => selected = i,
                  onSettings: () {},
                  accountBuilder: (_) => const Text('账户'),
                  menuOpen: menu,
                  glassMode: GlassMode.off,
                ),
              ),
            ),
          ),
        ),
      );
      double width() => tester.getSize(find.byType(AppSideNavigation)).width;
      await tester.pumpWidget(build());
      expect(width(), 96);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(400, 300));
      await mouse.moveTo(const Offset(40, 100));
      await tester.pump(const Duration(milliseconds: 119));
      expect(width(), 96);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 120));
      expect(width(), greaterThan(96));
      await mouse.moveTo(const Offset(500, 300));
      await tester.pump(const Duration(milliseconds: 179));
      expect(width(), greaterThan(96));
      await tester.pump(const Duration(milliseconds: 1));
      final beforeReverse = width();
      await tester.pump(const Duration(milliseconds: 80));
      expect(width(), lessThan(beforeReverse));
      await mouse.moveTo(const Offset(40, 100));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
      expect(width(), 216);
      await mouse.moveTo(tester.getCenter(find.text('趋势').last));
      await mouse.down(tester.getCenter(find.text('趋势').last));
      await mouse.up();
      expect(selected, 2);
      await mouse.moveTo(const Offset(500, 300));
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pumpAndSettle();
      expect(width(), 96);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(width(), 216);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.pumpWidget(build(menu: true, reduced: true));
      expect(width(), 216);
      await tester.pumpWidget(build(reduced: true));
      expect(width(), 96);
      await mouse.removePointer();
    },
  );

  testWidgets(
    'short sidebar large text scrolls to settings and account; touch logo toggles',
    (tester) async {
      var settings = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              disableAnimations: true,
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  height: 220,
                  child: AppSideNavigation(
                    destinations: _items,
                    selectedIndex: 0,
                    onSelected: (_) {},
                    onSettings: () => settings = true,
                    accountBuilder: (_) => const Text('账户'),
                    glassMode: GlassMode.off,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('膳食健康').first);
      await tester.pump();
      expect(tester.getSize(find.byType(AppSideNavigation)).width, 216);
      await tester.tap(find.text('膳食健康').last);
      await tester.pump();
      expect(tester.getSize(find.byType(AppSideNavigation)).width, 96);
      await tester.tap(find.text('膳食健康').first);
      await tester.pump();
      await tester.ensureVisible(find.text('设置').last);
      await tester.tap(find.text('设置').last);
      expect(settings, isTrue);
      await tester.ensureVisible(find.text('账户'));
      expect(find.text('账户').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Windows threshold and capture modes preserve page state and scroll',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(839, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final key = GlobalKey<_PageState>();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AppShell(
              location: '/home',
              child: _Page(key: key),
            ),
          ),
        ),
      );
      final state = key.currentState!;
      state.controller.jumpTo(180);
      await tester.pumpAndSettle();
      expect(find.byType(AppBottomNavigation), findsOneWidget);
      for (final width in [840.0, 1200.0, 839.0, 1000.0]) {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpAndSettle();
        expect(key.currentState, same(state));
        expect(state.controller.offset, 180);
        expect(
          find.byType(AppSideNavigation),
          width >= 840 ? findsOneWidget : findsNothing,
        );
        expect(
          tester.getTopLeft(find.byType(_Page)).dx,
          width >= 840 ? 120 : 0,
        );
      }
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(500, 400));
      await mouse.moveTo(const Offset(40, 100));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 120));
      expect(key.currentState, same(state));
      expect(state.controller.offset, 180);
      expect(tester.getTopLeft(find.byType(_Page)).dx, 120);
      await mouse.moveTo(const Offset(500, 400));
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      );
      for (final mode in GlassMode.values) {
        container.read(uiPreferencesProvider.notifier).setGlassMode(mode);
        await tester.pump();
        expect(key.currentState, same(state));
        expect(state.controller.offset, 180);
      }
      container
          .read(uiPreferencesProvider.notifier)
          .setGlassMode(GlassMode.standard);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('Android wide retains top navigation', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AppShell(location: '/home', child: SizedBox()),
        ),
      ),
    );
    expect(find.byType(AppSideNavigation), findsNothing);
    expect(find.byType(AppTopNavigation), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'nutrition grid paints and updates with unknown and zero values',
    (tester) async {
      Widget build(List<double?> values) => MaterialApp(
        home: Scaffold(
          body: NutritionBarChart(
            values: values,
            labels: const ['一', '二', '三'],
            highlightLast: true,
          ),
        ),
      );
      await tester.pumpWidget(build([1, null, 0]));
      await tester.pumpAndSettle();
      expect(find.text('未记录'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(build([10, null, 5]));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

class _Page extends StatefulWidget {
  const _Page({super.key});
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  final controller = ScrollController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    controller: controller,
    children: [
      for (var i = 0; i < 30; i++) SizedBox(height: 80, child: Text('Row $i')),
    ],
  );
}
