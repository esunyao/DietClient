# 首页导航

[根规范](../../../AGENTS.md) · [上级](../AGENTS.md) · [说明](doc/README.md)

入口：[home_screen.dart](presentation/screens/home_screen.dart)，按显式体验模式装配个人与机构内容；内部复用见 [widgets](presentation/widgets/AGENTS.md)。共享记录与体验模式见 [demo](../../demo/AGENTS.md)；跳转使用 [core](../../core/AGENTS.md) 的路径协议。个人与机构只改变内容重点，尺寸不决定身份。

个人营养目标入口见 [demo_nutrition_targets.dart](../../demo/demo_nutrition_targets.dart)，只读进度见 [personal_nutrition_summary.dart](presentation/widgets/personal_nutrition_summary.dart)，餐食仍用原 HomeMeals。

Android/Windows 真实分支见 [native_home_screen.dart](presentation/screens/native_home_screen.dart)，使用 dailySummary 和带当天日期的 meals 查询；入口装饰、快捷入口与餐食组件继续复用。Web 目标与样例只留在原演示分支。共享可见轮询见 [analysis_polling.dart](../../core/nutrition/application/analysis_polling.dart)，回归见 [nutrition_functional_test.dart](../../../test/nutrition_functional_test.dart)。

真实首页的当天查询与日期标题订阅 [current_date](../../core/presentation/current_date.dart)，跨午夜及恢复前台回归见 [frontend_navigation_test](../../../test/frontend_navigation_test.dart)；真实窄屏大字与独立失败重试见 [native_layout_test](../../../test/native_layout_test.dart)。
