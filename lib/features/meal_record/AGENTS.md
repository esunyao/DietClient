# 记录页面导航

- [根规范](../../../AGENTS.md) / [功能导航](../AGENTS.md) / [模块概览](doc/README.md)
- [记录这一餐入口](presentation/screens/recognition_screen.dart)：按共享原生功能开关装配真实采集；Web 与预览保留示例。
- [真实采集页](presentation/screens/native_recognition_screen.dart)：策略、服务端草稿、相机／选图、待上传区、进度、餐别与备注。
- [采集控制器](application/capture_controller.dart)：创建幂等键、逐图上传阶段、取消、恢复、授权复查与登录代次隔离。
- [共享真实契约](../../core/nutrition/application/nutrition_providers.dart) / [媒体协调器](../../core/media/media_coordinator.dart) / [AI 授权](../../core/privacy/ai_consent.dart)
- [聚焦回归](../../../test/meal_capture_functional_test.dart)：幂等重试、选择取消、串行阶段、部分失败重试、授权、异步受理、恢复与换号隔离。
- [共享演示状态](../../demo/demo_store.dart) / [公共路径](../../core/presentation/app_routes.dart)
- [公共组件](../../../packages/diet_ui/lib/diet_ui.dart)

本文件仅导航，规范以根 AGENTS 为准。

公开入口在创建状态前选择真实或私有演示采集页；入口隔离回归见 [entry_gateway_test.dart](../../../test/entry_gateway_test.dart)。

真实采集页借助 [共享离开保护](../../core/presentation/unsaved_form.dart) 在有本地待上传图片或备注时确认离开，处理中阻止离开；真实布局及提交失败保留输入见 [native_layout_test](../../../test/native_layout_test.dart)。
