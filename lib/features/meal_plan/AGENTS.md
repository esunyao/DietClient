# 配餐导航

- [根规范](../../../AGENTS.md) → [功能入口](../AGENTS.md) → [模块概览](doc/README.md)。
- 页面入口：[配餐](presentation/screens/meal_plan_screen.dart)；局部展示：[三方案比较与菜品行](presentation/widgets/meal_plan_widgets.dart)。
- 状态与样例见 [demo](../../demo/demo_store.dart)，共享展示组件见 [diet_ui](../../../packages/diet_ui/lib/diet_ui.dart)。
- 真实模式能力边界：[平台判定](../../core/config/ui_preview_config.dart) → [未支持页面](../../core/presentation/unsupported_feature_page.dart)；[回归](../../../test/unsupported_feature_test.dart)。
