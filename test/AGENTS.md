# 验证资源导航

[根规范与上级](../AGENTS.md) · [公开概览](doc/README.md) · [构建工具](../tool/AGENTS.md)

- [authentication_gate_test.dart](authentication_gate_test.dart)：应用配置、内存会话、门控与取消的离线回归入口
- [app_card_material_test.dart](app_card_material_test.dart)：共享卡片的列表 Material 背景、点击、开关及内边距回归
- 协议与执行器测试：[diet_oidc](../packages/diet_oidc/test/client_test.dart)、[diet_auth](../packages/diet_auth/test/flow_executor_test.dart)

测试使用本地替换边界，不代表真实身份提供方联通；执行结果见根说明。

实际执行入口与结果见 [根说明](../README.md)，功能、视觉和性能验收由用户进行。
