import 'dart:ui' show Tristate;

import 'package:diet_client/app/app_shell.dart';
import 'package:diet_client/core/config/ui_preview_config.dart';
import 'package:diet_client/core/presentation/app_routes.dart';
import 'package:diet_client/demo/demo_store.dart';
import 'package:diet_client/features/home/presentation/screens/home_screen.dart';
import 'package:diet_client/features/home/presentation/widgets/home_summary.dart';
import 'package:diet_client/features/meal/presentation/screens/meal_correction_screen.dart';
import 'package:diet_client/features/meal/presentation/screens/meal_history_screen.dart';
import 'package:diet_client/features/meal_plan/presentation/screens/meal_plan_screen.dart';
import 'package:diet_client/features/profile/presentation/screens/profile_screen.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('AppPage 滚动时保持标题和底部操作固定且末项可达', (tester) async {
    _setViewport(tester, const Size(430, 960));
    const footerKey = ValueKey('fixed-footer');
    const lastRowKey = ValueKey('last-row');
    var lastRowTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(430, 960),
            padding: EdgeInsets.only(top: 24, bottom: 34),
          ),
          child: AppPage(
            eyebrow: '10月2日 星期五',
            title: '固定标题',
            footer: SizedBox(
              key: footerKey,
              height: 48,
              child: FilledButton(onPressed: () {}, child: const Text('固定保存')),
            ),
            children: [
              for (var i = 0; i < 12; i++)
                SizedBox(
                  key: i == 11 ? lastRowKey : null,
                  height: 96,
                  child: TextButton(
                    onPressed: () {
                      if (i == 11) lastRowTaps++;
                    },
                    child: Text('条目 $i'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final titleRect = tester.getRect(find.text('固定标题'));
    expect(tester.widget<Text>(find.text('固定标题')).style?.fontSize, 28);
    expect(titleRect.left, 24);
    final footerRect = tester.getRect(find.byKey(footerKey));
    expect(titleRect.top, greaterThanOrEqualTo(24));
    expect(
      tester.getBottomLeft(find.text('10月2日 星期五')).dy,
      lessThanOrEqualTo(titleRect.top),
    );
    expect(footerRect.bottom, lessThanOrEqualTo(960 - 34));
    expect(footerRect.bottom, greaterThan(960 - 34 * 2));
    await tester.scrollUntilVisible(
      find.byKey(lastRowKey),
      240,
      scrollable: find.byType(Scrollable),
    );
    await tester.ensureVisible(find.byKey(lastRowKey));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('固定标题')), titleRect);
    expect(tester.getRect(find.byKey(footerKey)), footerRect);
    expect(
      tester.getRect(find.byKey(lastRowKey)).bottom,
      lessThanOrEqualTo(footerRect.top),
    );
    await tester.tap(find.text('条目 11'));
    await tester.pumpAndSettle();
    expect(lastRowTaps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('横屏键盘下演示手工记录可编辑且保存操作可达', (tester) async {
    _setViewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetViewInsets);
    await _pumpShell(
      tester,
      initialLocation: AppRoutes.manualMeal,
      page: const MealCorrectionScreen(),
    );
    final field = find.ancestor(
      of: find.text('餐食名称'),
      matching: find.byType(TextFormField),
    );
    final editable = find.descendant(
      of: field,
      matching: find.byType(EditableText),
    );
    final formState = tester.state<FormState>(find.byType(Form));
    final fieldState = tester.state(field);
    final scrollable = find
        .descendant(of: find.byType(AppPage), matching: find.byType(Scrollable))
        .first;
    final scrollState = tester.state<ScrollableState>(scrollable);
    await tester.enterText(field, '横屏输入');
    final focusNode = tester.widget<EditableText>(editable).focusNode;
    expect(focusNode.hasFocus, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final topBar = tester.getRect(find.byType(AppTopNavigation));
    expect(AppPageScope.of(tester.element(find.byType(AppPage)))?.topInset, 84);
    expect(topBar.bottom, lessThanOrEqualTo(84));
    expect(tester.state(field), same(fieldState));
    expect(tester.state<FormState>(find.byType(Form)), same(formState));
    expect(tester.state<ScrollableState>(scrollable), same(scrollState));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    final inputRect = tester.getRect(field);
    expect(inputRect.top, greaterThanOrEqualTo(84));
    expect(inputRect.bottom, lessThanOrEqualTo(190));
    expect(editable.hitTestable(), findsOneWidget);
    await tester.enterText(field, '键盘打开后仍可输入');
    expect(tester.widget<EditableText>(editable).controller.text, '键盘打开后仍可输入');
    expect(focusNode.hasFocus, isTrue);

    final save = find.text('保存记录（演示）');
    await tester.scrollUntilVisible(save, 160, scrollable: scrollable);
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    expect(save.hitTestable(), findsOneWidget);
    expect(tester.getRect(save).top, greaterThanOrEqualTo(84));
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(190));
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('请选择餐别'), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.state(field), same(fieldState));
    expect(tester.state<FormState>(find.byType(Form)), same(formState));
    expect(tester.state<ScrollableState>(scrollable), same(scrollState));
    expect(tester.widget<EditableText>(editable).controller.text, '键盘打开后仍可输入');
    await tester.showKeyboard(field);
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    await tester.pumpAndSettle();
    await tester.ensureVisible(editable);
    await tester.pumpAndSettle();
    expect(tester.state(field), same(fieldState));
    expect(tester.widget<EditableText>(editable).focusNode, same(focusNode));
    expect(focusNode.hasFocus, isTrue);
    expect(tester.widget<EditableText>(editable).controller.text, '键盘打开后仍可输入');
    expect(editable.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('常规与短视口切换保留内部表单状态焦点和滚动位置', (tester) async {
    _setViewport(tester, const Size(1194, 834));
    addTearDown(tester.view.resetViewInsets);
    var saves = 0;
    await _pumpShell(
      tester,
      initialLocation: AppRoutes.manualMeal,
      page: AppPage(
        title: '保留编辑草稿',
        showBack: true,
        footer: SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: () => saves++,
            child: const Text('保存内部草稿'),
          ),
        ),
        children: [
          Form(
            child: Column(
              children: [
                const SizedBox(height: 320),
                TextFormField(
                  initialValue: '初始内容',
                  decoration: const InputDecoration(labelText: '内部编辑字段'),
                ),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ],
      ),
    );
    final field = find.byType(TextFormField);
    final editable = find.byType(EditableText);
    final formState = tester.state<FormState>(find.byType(Form));
    final fieldState = tester.state(field);
    final scrollable = find
        .descendant(of: find.byType(AppPage), matching: find.byType(Scrollable))
        .first;
    final scrollState = tester.state<ScrollableState>(scrollable);
    scrollState.position.jumpTo(180);
    await tester.enterText(field, '没有外部控制器的草稿');
    await tester.pumpAndSettle();
    final focusNode = tester.widget<EditableText>(editable).focusNode;
    final titleRect = tester.getRect(find.text('保留编辑草稿'));
    final footerRect = tester.getRect(find.text('保存内部草稿'));
    scrollState.position.jumpTo(220);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('保留编辑草稿')), titleRect);
    expect(tester.getRect(find.text('保存内部草稿')), footerRect);

    tester.view.physicalSize = const Size(844, 390);
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.state(field), same(fieldState));
    expect(tester.state<FormState>(find.byType(Form)), same(formState));
    expect(tester.state<ScrollableState>(scrollable), same(scrollState));
    expect(tester.widget<EditableText>(editable).focusNode, same(focusNode));
    expect(focusNode.hasFocus, isTrue);
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    expect(tester.getRect(field).top, greaterThanOrEqualTo(84));
    expect(tester.getRect(field).bottom, lessThanOrEqualTo(190));
    expect(editable.hitTestable(), findsOneWidget);
    expect(tester.widget<EditableText>(editable).controller.text, '没有外部控制器的草稿');

    tester.view.viewInsets = const FakeViewPadding();
    tester.view.physicalSize = const Size(1194, 834);
    await tester.pumpAndSettle();
    expect(tester.state(field), same(fieldState));
    expect(tester.state<FormState>(find.byType(Form)), same(formState));
    expect(tester.state<ScrollableState>(scrollable), same(scrollState));
    expect(scrollState.position.pixels, greaterThan(0));
    expect(focusNode.hasFocus, isTrue);
    expect(tester.widget<EditableText>(editable).controller.text, '没有外部控制器的草稿');
    expect(tester.getRect(find.text('保留编辑草稿')), titleRect);
    expect(tester.getRect(find.text('保存内部草稿')), footerRect);
    await tester.tap(find.text('保存内部草稿'));
    expect(saves, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('手机二级标题居中使用 23 字号并保留左侧返回命中区', (tester) async {
    _setViewport(tester, const Size(430, 960));
    var backTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppPageScope(
          onBackFallback: () => backTaps++,
          child: const AppPage(
            title: '二级标题',
            showBack: true,
            children: [Text('二级内容')],
          ),
        ),
      ),
    );
    final title = find.text('二级标题');
    final back = find.byTooltip('返回');
    final titleRect = tester.getRect(title);
    final backRect = tester.getRect(back);
    expect(tester.widget<Text>(title).style?.fontSize, 23);
    expect(titleRect.center.dx, closeTo(215, .1));
    expect(backRect.width, greaterThanOrEqualTo(44));
    expect(backRect.height, greaterThanOrEqualTo(44));
    expect(backRect.right, lessThan(titleRect.left));
    expect(titleRect.bottom, lessThan(tester.getTopLeft(find.text('二级内容')).dy));
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(backTaps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AdaptiveColumns 在 1194 视口使用 754/352 双栏及 24 间距', (tester) async {
    _setViewport(tester, const Size(1194, 834));
    const mainKey = ValueKey('main-column');
    const asideKey = ValueKey('aside-column');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: AdaptiveColumns(
              main: const [SizedBox(key: mainKey, height: 80)],
              aside: const [SizedBox(key: asideKey, height: 80)],
            ),
          ),
        ),
      ),
    );
    final mainRect = tester.getRect(find.byKey(mainKey));
    final asideRect = tester.getRect(find.byKey(asideKey));
    expect(mainRect.left, 32);
    expect(mainRect.width, closeTo(754, .1));
    expect(asideRect.width, closeTo(352, .1));
    expect(asideRect.left - mainRect.right, closeTo(24, .1));
    expect(asideRect.top, mainRect.top);
    expect(asideRect.right, closeTo(1194 - 32, .1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AdaptiveColumns 在宽窗口的窄父约束中退回单栏', (tester) async {
    _setViewport(tester, const Size(1194, 834));
    const mainKey = ValueKey('constrained-main');
    const asideKey = ValueKey('constrained-aside');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 430,
              child: AdaptiveColumns(
                main: [SizedBox(key: mainKey, height: 80)],
                aside: [SizedBox(key: asideKey, height: 80)],
              ),
            ),
          ),
        ),
      ),
    );
    final mainRect = tester.getRect(find.byKey(mainKey));
    final asideRect = tester.getRect(find.byKey(asideKey));
    expect(mainRect.width, 430);
    expect(asideRect.width, 430);
    expect(asideRect.left, mainRect.left);
    expect(asideRect.top, greaterThanOrEqualTo(mainRect.bottom));
    expect(tester.takeException(), isNull);
  });
  testWidgets('手机导航为 58 高且无常驻退出行并保留选中语义与路由', (tester) async {
    _setViewport(tester, const Size(430, 960));
    final semantics = tester.ensureSemantics();
    try {
      final router = await _pumpShell(tester);
      final navigationRect = tester.getRect(find.byType(AppBottomNavigation));
      expect(navigationRect.height, 58);
      expect(navigationRect.left, 45);
      expect(navigationRect.right, 430 - 45);
      expect(find.byType(AppTopNavigation), findsNothing);
      for (final label in ['首页', '配餐', '趋势', '我的']) {
        expect(tester.widget<Text>(find.text(label)).style?.fontSize, 11);
      }
      expect(
        tester
            .getSemantics(find.text('首页'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.text('配餐'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );
      expect(find.text('退出当前应用'), findsNothing);
      expect(find.byTooltip('退出当前应用'), findsNothing);
      expect(
        tester.getBottomLeft(find.text('${AppRoutes.home} 页面')).dy,
        lessThan(tester.getTopLeft(find.text('页面内容')).dy),
      );
      expect(
        tester.getBottomLeft(find.text('页面内容')).dy,
        lessThan(tester.getTopLeft(find.text('首页')).dy),
      );
      await tester.tap(find.text('配餐'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.mealPlan,
      );
      expect(find.text('${AppRoutes.mealPlan} 页面'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.text('配餐'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.text('首页'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('窄屏大字保持标题、内容与导航可用且不关闭文字缩放', (tester) async {
    _setViewport(tester, const Size(320, 720));
    final router = await _pumpShell(tester, textScale: 1.6);
    final navigationRect = tester.getRect(find.byType(AppBottomNavigation));
    expect(navigationRect.height, greaterThan(58));
    expect(
      MediaQuery.textScalerOf(tester.element(find.text('我的'))).scale(12),
      closeTo(19.2, .01),
    );
    final titleRect = tester.getRect(find.text('${AppRoutes.home} 页面'));
    final contentRect = tester.getRect(find.text('页面内容'));
    expect(titleRect.bottom, lessThanOrEqualTo(contentRect.top));
    expect(contentRect.bottom, lessThan(tester.getTopLeft(find.text('首页')).dy));
    for (final label in ['首页', '配餐', '趋势', '我的']) {
      expect(find.text(label).hitTestable(), findsOneWidget);
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.bottom, lessThanOrEqualTo(720));
      expect(rect.top, greaterThanOrEqualTo(navigationRect.top));
      expect(rect.bottom, lessThanOrEqualTo(navigationRect.bottom));
    }
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.profile);
    expect(find.text('退出当前应用'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('演示个人首页按记录、三快捷、营养、餐食顺序展示', (tester) async {
    _setViewport(tester, const Size(430, 960));
    await _pumpShell(tester, home: true);
    final titleRect = tester.getRect(find.text('今天，好好吃饭'));
    final recordRect = tester.getRect(
      find.ancestor(of: find.text('拍照记一餐'), matching: find.byType(AppCard)),
    );
    final manualRect = tester.getRect(find.text('手工记录'));
    final historyRect = tester.getRect(find.text('历史记录'));
    final recordsRect = tester.getRect(find.text('健康档案'));
    final nutritionRect = tester.getRect(
      find.ancestor(of: find.text('今日营养'), matching: find.byType(AppCard)),
    );
    final mealsRect = tester.getRect(find.text('今天吃了什么'));
    expect(titleRect.bottom, lessThan(recordRect.top));
    expect(recordRect.left, 20);
    expect(recordRect.width, 390);
    expect(recordRect.height, inInclusiveRange(140, 160));
    expect(recordRect.bottom, lessThan(manualRect.top));
    expect(manualRect.top, historyRect.top);
    expect(historyRect.top, recordsRect.top);
    expect(manualRect.right, lessThan(historyRect.left));
    expect(historyRect.right, lessThan(recordsRect.left));
    expect(recordsRect.bottom, lessThan(nutritionRect.top));
    expect(nutritionRect.height, inInclusiveRange(230, 270));
    expect(nutritionRect.bottom, lessThan(mealsRect.top));
    expect(find.text('1,100'), findsOneWidget);
    expect(find.text('拍照记录').hitTestable(), findsOneWidget);
    expect(find.text('今天吃了什么').hitTestable(), findsOneWidget);
    expect(find.text('机构晚餐'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('390演示个人首页快捷横排且营养保持紧凑，餐食保留24边距', (tester) async {
    _setViewport(tester, const Size(390, 900));
    await _pumpShell(tester, home: true);
    final quick = tester.getRect(find.text('手工记录'));
    final icon = tester.getRect(find.byIcon(AppIcons.edit));
    expect((quick.center.dy - icon.center.dy).abs(), lessThan(2));
    final nutrition = tester.getRect(
      find.ancestor(of: find.text('今日营养'), matching: find.byType(AppCard)),
    );
    expect(nutrition.height, inInclusiveRange(230, 270));
    final meals = tester.getRect(
      find.ancestor(of: find.text('今天吃了什么'), matching: find.byType(HomeMeals)),
    );
    expect(meals.left, 24);
    expect(tester.takeException(), isNull);
  });

  testWidgets('演示平板机构首页将待确认晚餐放在营养与餐食右侧', (tester) async {
    _setViewport(tester, const Size(1194, 834));
    await _pumpShell(tester, home: true, mode: ExperienceMode.institution);
    expect(find.byType(AppBottomNavigation), findsNothing);
    expect(find.byType(AppTopNavigation), findsOneWidget);
    final titleRect = tester.getRect(find.text('今天的膳食，一眼看清'));
    final nutritionRect = tester.getRect(
      find.ancestor(of: find.text('今日已记录营养'), matching: find.byType(AppCard)),
    );
    final dinnerRect = tester.getRect(
      find.ancestor(of: find.text('机构晚餐'), matching: find.byType(AppCard)),
    );
    final mealsRect = tester.getRect(find.text('今天吃了什么'));
    expect(titleRect.bottom, lessThan(nutritionRect.top));
    expect(nutritionRect.left, 32);
    expect(nutritionRect.width, closeTo(754, .1));
    expect(dinnerRect.width, closeTo(352, .1));
    expect(dinnerRect.left - nutritionRect.right, closeTo(24, .1));
    expect(dinnerRect.top, nutritionRect.top);
    expect(mealsRect.top, greaterThanOrEqualTo(nutritionRect.bottom));
    expect(mealsRect.right, lessThan(dinnerRect.left));
    expect(find.text('待本人确认'), findsOneWidget);
    expect(find.text('确认实际用餐前，不计入摄入'), findsOneWidget);
    expect(find.text('1,100'), findsOneWidget);
    expect(find.text('核对机构餐食').hitTestable(), findsOneWidget);
    expect(tester.getBottomLeft(find.text('首页')).dy, lessThan(titleRect.top));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('配餐页在 430 手机首帧与短滚动无布局异常', (tester) async {
    _setViewport(tester, const Size(430, 960));
    await _pumpShell(
      tester,
      initialLocation: AppRoutes.mealPlan,
      page: const MealPlanScreen(),
    );
    expect(find.byType(MealPlanScreen), findsOneWidget);
    expect(find.text('下一餐怎么吃'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find
          .descendant(
            of: find.byType(AppPage),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('饮食历史在 1194 平板首帧与短滚动无布局异常', (tester) async {
    _setViewport(tester, const Size(1194, 834));
    await _pumpShell(
      tester,
      initialLocation: AppRoutes.mealHistory,
      page: const MealHistoryScreen(),
    );
    expect(find.byType(MealHistoryScreen), findsOneWidget);
    expect(find.text('饮食历史'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find
          .descendant(
            of: find.byType(AppPage),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('我的页在 360 手机与 1.3 倍文字首帧和短滚动无布局异常', (tester) async {
    _setViewport(tester, const Size(360, 800));
    await _pumpShell(
      tester,
      initialLocation: AppRoutes.profile,
      page: const ProfileScreen(),
      textScale: 1.3,
    );
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('资料与健康管理'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find
          .descendant(
            of: find.byType(AppPage),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<GoRouter> _pumpShell(
  WidgetTester tester, {
  bool home = false,
  ExperienceMode mode = ExperienceMode.personal,
  double textScale = 1,
  String initialLocation = AppRoutes.home,
  Widget? page,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          for (final path in [
            AppRoutes.home,
            AppRoutes.mealPlan,
            AppRoutes.trends,
            AppRoutes.profile,
            if (initialLocation == AppRoutes.mealHistory) AppRoutes.mealHistory,
            if (initialLocation == AppRoutes.manualMeal) AppRoutes.manualMeal,
          ])
            GoRoute(
              path: path,
              builder: (_, _) => page != null && path == initialLocation
                  ? page
                  : home && path == AppRoutes.home
                  ? const HomeScreen()
                  : AppPage(title: '$path 页面', children: const [Text('页面内容')]),
            ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      // 这些几何与键盘回归使用演示页面，真实数据与未支持边界由各自测试覆盖。
      overrides: [
        nativeNutritionEnabledProvider.overrideWithValue(false),
        demoProvider.overrideWith(() => _LayoutDemoController(mode)),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

class _LayoutDemoController extends DemoController {
  _LayoutDemoController(this.mode);

  final ExperienceMode mode;

  @override
  DemoSnapshot build() => DemoSnapshot(meals: initialMeals(), mode: mode);
}
