import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/app/app_shell.dart';
import 'package:diet_client/core/presentation/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
// Inspect the design-system backend contract without exposing it in app code.
// ignore: depend_on_referenced_packages
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() {
  testWidgets('Windows capture stays stable and disabled modes stop pumping', (
    tester,
  ) async {
    final backgroundKey = GlobalKey<_BackgroundState>();
    Widget build(
      GlassMode mode, {
      bool reduce = false,
      bool contrast = false,
    }) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(highContrast: contrast),
        child: Scaffold(
          body: GlassBackdrop(
            mode: mode,
            reduceTransparency: reduce,
            background: _Background(key: backgroundKey),
            overlay: Align(
              alignment: Alignment.bottomCenter,
              child: GlassSurface(
                mode: mode,
                reduceTransparency: reduce,
                child: const Text('Navigation'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(build(GlassMode.standard));
    final state = backgroundKey.currentState;
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pump();
    final scrollOffset = state!.controller.offset;
    expect(scrollOffset, greaterThan(0));
    final view = tester.state(find.byType(LiquidGlassView));
    expect(GlassSurface.supportsEnhanced, isTrue);
    final config = tester.widget<LiquidGlassView>(find.byType(LiquidGlassView));
    expect(config.useImpellerBackdrop, isFalse);
    expect(config.pixelRatio, 1);
    expect(config.useSync, isTrue);
    expect(config.refreshRate, LiquidGlassRefreshRate.high);
    for (final mode in GlassMode.values) {
      await tester.pumpWidget(build(mode));
      await tester.pump();
      expect(backgroundKey.currentState, same(state));
      expect(state.controller.offset, scrollOffset);
      expect(tester.state(find.byType(LiquidGlassView)), same(view));
      expect(find.byType(_Background), findsOneWidget);
    }
    for (final accessible in [false, true]) {
      await tester.pumpWidget(
        build(GlassMode.enhanced, reduce: !accessible, contrast: accessible),
      );
      expect(
        tester
            .widget<LiquidGlassView>(find.byType(LiquidGlassView))
            .realTimeCapture,
        isFalse,
      );
      final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      expect(filter.enabled, isFalse);
    }
    await tester.pumpWidget(build(GlassMode.standard));
    expect(
      tester
          .widget<LiquidGlassView>(find.byType(LiquidGlassView))
          .realTimeCapture,
      isFalse,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('AppPage 顶部覆盖量移动固定标题但保留业务滚动位置', (tester) async {
    Widget build(double inset) => MaterialApp(
      theme: AppTheme.light,
      home: AppPageScope(
        topInset: inset,
        onBackFallback: () {},
        child: AppPage(
          title: 'Page',
          children: [
            for (var i = 0; i < 20; i++)
              SizedBox(height: 80, child: Text('Content $i')),
          ],
        ),
      ),
    );
    await tester.pumpWidget(build(0));
    final headerTop = tester.getTopLeft(find.text('Page')).dy;
    await tester.drag(find.byType(Scrollable), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Page')).dy, headerTop);
    final contentTop = tester.getTopLeft(find.text('Content 4')).dy;
    await tester.pumpWidget(build(84));
    expect(tester.getTopLeft(find.text('Page')).dy, headerTop + 84);
    expect(tester.getTopLeft(find.text('Content 4')).dy, contentTop + 84);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Windows wide floating navigation routes clicks', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              AppShell(location: state.uri.path, child: child),
          routes: [
            for (final path in [AppRoutes.home, AppRoutes.mealPlan])
              GoRoute(
                path: path,
                builder: (_, _) => AppPage(title: path, children: const []),
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GlassBackdrop), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(AppRoutes.home)).dy,
      greaterThan(tester.getBottomLeft(find.text('首页')).dy),
    );
    await tester.tap(find.text('配餐'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.mealPlan);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}

class _Background extends StatefulWidget {
  const _Background({super.key});
  @override
  State<_Background> createState() => _BackgroundState();
}

class _BackgroundState extends State<_Background> {
  final controller = ScrollController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.green,
    child: ListView(
      controller: controller,
      children: [
        for (var i = 0; i < 30; i++)
          SizedBox(height: 80, child: Text('Row $i')),
      ],
    ),
  );
}
