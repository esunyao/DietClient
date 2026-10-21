# 餐食页面导航

- [根规范](../../../AGENTS.md) / [功能导航](../AGENTS.md) / [模块概览](doc/README.md) / [展示导航](presentation/AGENTS.md)
- [饮食历史](presentation/screens/meal_history_screen.dart)：日期、餐别、关键词筛选与分页。
- [单餐详情](presentation/screens/meal_detail_screen.dart)：来源、分析状态、已知与未知营养。
- [修正与手工新建](presentation/screens/meal_correction_screen.dart)：编辑草稿、离开保护及内存保存。
- [展示组件](presentation/widgets/meal_widgets.dart) / [共享演示状态](../../demo/demo_store.dart) / [展示模型](../../../packages/diet_models/lib/diet_models.dart)

本文件仅导航，规范以根 AGENTS 为准。

Android/Windows 真实入口为同目录 `native_meal_*_screen.dart`，平台开关在原页面入口；Web 保留原演示。逐菜修正载荷见 [meal_edit.dart](application/meal_edit.dart)，共享查询与可见轮询见 [nutrition](../../core/nutrition/application/nutrition_providers.dart) 和 [analysis_polling.dart](../../core/nutrition/application/analysis_polling.dart)。聚焦回归见 [meal_functional_test.dart](../../../test/meal_functional_test.dart)。
