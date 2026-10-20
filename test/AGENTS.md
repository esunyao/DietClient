# 验证资源导航

[根规范与上级](../AGENTS.md) · [公开概览](doc/README.md) · [构建工具](../tool/AGENTS.md)

- [authentication_gate_test.dart](authentication_gate_test.dart)：应用配置、内存会话、门控与取消的离线回归入口
- [app_card_material_test.dart](app_card_material_test.dart)：共享卡片的列表 Material 背景、点击、开关及内边距回归
- [glass_backdrop_test.dart](glass_backdrop_test.dart)：Windows 捕获配置、禁用和无障碍、背景状态、固定标题覆盖量与导航点击；不代表视觉或性能验收
- [navigation_interaction_test.dart](navigation_interaction_test.dart)：三态、拖动提交/取消、迷你首次展开与键盘、真实 AppShell 滚动和状态保留、营养未知/超额
- [ui_layout_test.dart](ui_layout_test.dart)：430 手机、1194 平板与窄屏大字的一级/二级标题对齐、滚动/固定操作、约束双栏、导航与首页内容顺序回归；另含配餐、历史、我的三处代表性首帧/短滚动，以及844×390横屏键盘下真实手工页可编辑、footer可达与表单状态保留检查
- 协议与执行器测试：[diet_oidc](../packages/diet_oidc/test/client_test.dart)、[diet_auth](../packages/diet_auth/test/flow_executor_test.dart)

测试使用本地替换边界，不代表真实身份提供方联通；执行结果见根说明。

实际执行入口与结果见 [根说明](../README.md)，功能、视觉和性能验收由用户进行。

- [desktop_sidebar_preview_test.dart](desktop_sidebar_preview_test.dart)：平台/编译开关、预览首页与深链接、无认证网关构造、隐私遮罩、侧栏定时/反向/键盘/鼠标/触摸/短视口、跨断点状态和图表绘制。
- [desktop_sidebar_motion_test.dart](desktop_sidebar_motion_test.dart)：统一进度同目标去重、反向剩余时长、单图标中间帧、稳定文字槽位与单份语义、途中减少动态，以及真实 AppShell 账户／菜单实例保持、长名大字和短窗口；不代表真实窗口视觉或帧率验收。
