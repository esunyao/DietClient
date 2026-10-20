import 'package:diet_client/app/navigation_collapse_controller.dart';
import 'package:diet_client/app/app_shell.dart';
import 'package:diet_client/demo/demo_store.dart';
import 'package:diet_client/features/home/presentation/widgets/personal_nutrition_summary.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const destinations = [
  AppNavigationDestination(label: '首页', icon: Icons.home),
  AppNavigationDestination(label: '配餐', icon: Icons.restaurant),
  AppNavigationDestination(label: '趋势', icon: Icons.timeline),
  AppNavigationDestination(label: '我的', icon: Icons.person),
];

void main() {
  testWidgets(
    'AppShell user scroll collapses overlay while programmatic scroll and page state stay stable',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pageKey = GlobalKey<_ScrollPageState>();
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          ShellRoute(
            builder: (context, state, child) =>
                AppShell(location: state.uri.path, child: child),
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, _) => _ScrollPage(key: pageKey),
              ),
              GoRoute(path: '/meal-plan', builder: (_, _) => const SizedBox()),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      final state = pageKey.currentState!;
      state.controller.jumpTo(250);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
            .displayState,
        AppNavigationState.full,
      );
      state.controller.animateTo(
        500,
        duration: const Duration(milliseconds: 1),
        curve: Curves.linear,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
            .displayState,
        AppNavigationState.full,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
            .displayState,
        AppNavigationState.mini,
      );
      final offset = state.controller.offset;
      await tester.tap(find.byType(TextButton).at(1));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(pageKey.currentState, same(state));
      expect(state.controller.offset, offset);
      expect(
        tester
            .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
            .displayState,
        AppNavigationState.full,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -160));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 60));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
            .displayState,
        AppNavigationState.full,
      );
      expect(pageKey.currentState, same(state));
    },
  );
  testWidgets('drag previews multiple tabs and commits once; cancel restores', (
    tester,
  ) async {
    final selections = <int>[];
    final interactions = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppBottomNavigation(
              destinations: destinations,
              selectedIndex: 0,
              onSelected: selections.add,
              onInteractionChanged: interactions.add,
            ),
          ),
        ),
      ),
    );
    final bounds = tester.getRect(find.byType(AppBottomNavigation));
    final start = Offset(bounds.left + bounds.width / 8, bounds.center.dy);
    final gesture = await tester.startGesture(start);
    expect(interactions.last, isTrue);
    final second = await tester.startGesture(
      start + const Offset(50, 0),
      pointer: 2,
    );
    await second.up();
    expect(interactions.last, isTrue);
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(140, 0));
    await tester.pump();
    expect(selections, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selections, [3]);
    expect(interactions.last, isFalse);
    selections.clear();
    final cancelled = await tester.startGesture(start);
    await cancelled.moveBy(const Offset(200, 0));
    await tester.pump();
    await cancelled.cancel();
    await tester.pumpAndSettle();
    expect(selections, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'three states remain visible; mini first gesture only expands, keyboard then selects',
    (tester) async {
      var progress = 0.0;
      final selections = <int>[];
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Center(
                  child: AppBottomNavigation(
                    destinations: destinations,
                    selectedIndex: 0,
                    collapseProgress: progress,
                    onSelected: selections.add,
                    onExpand: () => setState(() => progress = 0),
                  ),
                );
              },
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(AppBottomNavigation)),
        const Size(340, 58),
      );
      rebuild(() => progress = 1);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(AppBottomNavigation)),
        const Size(248, 48),
      );
      rebuild(() => progress = 2);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(AppBottomNavigation)),
        const Size(184, 44),
      );
      for (final button in tester.widgetList<TextButton>(
        find.byType(TextButton),
      )) {
        expect(
          button.style!.minimumSize!.resolve({})!.height,
          greaterThanOrEqualTo(44),
        );
      }
      final firstMini = await tester.startGesture(
        tester.getCenter(find.byType(TextButton).at(2)),
      );
      await firstMini.moveBy(const Offset(35, 0));
      await firstMini.up();
      await tester.pumpAndSettle();
      expect(progress, 0);
      expect(selections, isEmpty);
      Focus.of(tester.element(find.text('趋势'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selections, [2]);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: AppBottomNavigation(
                  destinations: destinations,
                  selectedIndex: 0,
                  collapseProgress: 2,
                  onSelected: selections.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.getSize(find.byType(AppBottomNavigation)),
        const Size(184, 44),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'collapse filters programmatic, horizontal and nested scroll; reverse/top restore',
    (tester) async {
      final controller = NavigationCollapseController();
      addTearDown(controller.dispose);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      FixedScrollMetrics metrics({
        double pixels = 200,
        AxisDirection axis = AxisDirection.down,
      }) => FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 1000,
        pixels: pixels,
        viewportDimension: 500,
        axisDirection: axis,
        devicePixelRatio: 1,
      );
      void start({bool user = true, AxisDirection axis = AxisDirection.down}) =>
          controller.handle(
            ScrollStartNotification(
              metrics: metrics(axis: axis),
              context: context,
              dragDetails: user ? DragStartDetails() : null,
            ),
          );
      void update(
        double delta, {
        double pixels = 200,
        AxisDirection axis = AxisDirection.down,
      }) => controller.handle(
        ScrollUpdateNotification(
          metrics: metrics(pixels: pixels, axis: axis),
          context: context,
          scrollDelta: delta,
        ),
      );
      start(user: false);
      update(200);
      expect(controller.value, 0);
      start(axis: AxisDirection.right);
      update(200, axis: AxisDirection.right);
      expect(controller.value, 0);
      start();
      update(24);
      expect(controller.value, 1);
      update(96);
      expect(controller.value, 2);
      update(-6);
      expect(controller.value, 2);
      update(-6);
      expect(controller.value, 0);
      update(120);
      expect(controller.value, 2);
      update(-3, pixels: 0);
      expect(controller.value, 0);
      update(120, pixels: 1100);
      expect(controller.value, 0);
      controller.interacting = true;
      update(120);
      expect(controller.value, 0);
      controller.interacting = false;
      controller.handle(
        ScrollEndNotification(metrics: metrics(), context: context),
      );
      update(200);
      expect(controller.value, 0);
      // Real nested notifications acquire depth while bubbling through a viewport.
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationListener<ScrollNotification>(
            onNotification: controller.handle,
            child: ListView(
              children: [
                SizedBox(
                  height: 200,
                  child: ListView(children: const [SizedBox(height: 900)]),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.drag(find.byType(ListView).last, const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(controller.value, 0);
    },
  );

  testWidgets(
    'nutrition preserves unknown and over-target numbers with bounded bars',
    (tester) async {
      Future<void> render(Nutrients nutrients, {double scale = 1}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: PersonalNutritionSummary(
                    data: DemoSnapshot(
                      meals: [
                        MealEntry(
                          id: 'test',
                          title: 'test',
                          type: MealType.lunch,
                          consumedAt: demoDate,
                          nutrients: nutrients,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await render(const Nutrients());
      expect(find.text('未知'), findsNWidgets(4));
      expect(find.text('剩余未知'), findsOneWidget);
      await render(
        const Nutrients(energy: 3600, protein: 180, carbs: 500, fat: 120),
        scale: 2,
      );
      expect(find.text('200%'), findsNWidgets(4));
      expect(find.text('3,600'), findsOneWidget);
      for (final bar in tester.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      )) {
        expect(bar.value, 1);
      }
      expect(tester.takeException(), isNull);
    },
  );
}

class _ScrollPage extends StatefulWidget {
  const _ScrollPage({super.key});
  @override
  State<_ScrollPage> createState() => _ScrollPageState();
}

class _ScrollPageState extends State<_ScrollPage> {
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
      for (var i = 0; i < 40; i++) SizedBox(height: 80, child: Text('Item $i')),
    ],
  );
}
