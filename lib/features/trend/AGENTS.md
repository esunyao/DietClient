# 营养趋势导航

- [根规范](../../../AGENTS.md) → [功能入口](../AGENTS.md) → [模块概览](doc/README.md)。
- 页面入口：[营养趋势](presentation/screens/trends_screen.dart)；局部展示：[覆盖、口径与逐日表](presentation/widgets/trend_widgets.dart)。
- 状态与样例见 [demo](../../demo/demo_store.dart)，共享展示组件见 [diet_ui](../../../packages/diet_ui/lib/diet_ui.dart)。

- Android/Windows 的 [native_trends_screen.dart](presentation/screens/native_trends_screen.dart) 使用真实 daily-trend；原页面按平台开关保留 Web 演示。未知/零与统计口径回归见 [nutrition_functional_test.dart](../../../test/nutrition_functional_test.dart)。

真实趋势的日期窗口订阅 [共享本地日期](../../core/presentation/current_date.dart)，随本地跨日更新，不覆盖用户选择的周期与营养素。
