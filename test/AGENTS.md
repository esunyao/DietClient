# 验证资源导航

[根规范与上级](../AGENTS.md) · [公开概览](doc/README.md) · [构建工具](../tool/AGENTS.md)

- [authentication_gate_test.dart](authentication_gate_test.dart)：应用配置、内存会话、门控与取消的离线回归入口
- [app_card_material_test.dart](app_card_material_test.dart)：共享卡片的列表 Material 背景、点击、开关及内边距回归
- [glass_backdrop_test.dart](glass_backdrop_test.dart)：Windows 捕获配置、禁用和无障碍、背景状态、固定标题覆盖量与导航点击；不代表视觉或性能验收
- [ui_layout_test.dart](ui_layout_test.dart)：430 手机、1194 平板与窄屏大字的一级/二级标题对齐、滚动/固定操作、约束双栏、导航与首页内容顺序回归；另含配餐、历史、我的三处代表性首帧/短滚动检查
- 协议与执行器测试：[diet_oidc](../packages/diet_oidc/test/client_test.dart)、[diet_auth](../packages/diet_auth/test/flow_executor_test.dart)

测试使用本地替换边界，不代表真实身份提供方联通；执行结果见根说明。

实际执行入口与结果见 [根说明](../README.md)，功能、视觉和性能验收由用户进行。
