# 餐食展示导航

[根规范](../../../../AGENTS.md) · [上级导航](../AGENTS.md) · [模块概览](../doc/README.md)

- 页面一页一文件：[历史](screens/meal_history_screen.dart)、[详情](screens/meal_detail_screen.dart)、[修正与手工新建](screens/meal_correction_screen.dart)。
- 内部复用：[日期时间、餐食行与整餐营养](widgets/meal_widgets.dart)。不从其他 feature 导入展示组件。
- 状态仍由 [demo](../../../demo/AGENTS.md) 提供；页面布局与 tokens 复用 [diet_ui](../../../../packages/diet_ui/AGENTS.md)，不重复消费安全区。
