# Dart 源码导航

[根规范与上级](../AGENTS.md) · [公开概览](../doc/README.md) · [架构](../doc/architecture.md) · [UI 规格](../doc/ui-spec.md)

本文件只导航，不新增规范。源码职责依次为启动 → app 装配 → feature 页面 → core/demo/共享包；现有认证与业务演示使用不同的内存状态入口。

| 任务 | 读什么 |
|---|---|
| 启动、登录门控、路由与导航装配 | [main.dart](main.dart) → [app/AGENTS](app/AGENTS.md) |
| 配置、会话、路径和展示偏好 | [core/AGENTS](core/AGENTS.md) |
| 共享业务演示值与修正联动 | [demo/AGENTS](demo/AGENTS.md) |
| 页面布局、表单和局部交互 | [features/AGENTS](features/AGENTS.md) → 对应 feature 的 doc 与源码 |
| 共享模型、组件、图表和玻璃 | [packages/AGENTS](../packages/AGENTS.md) → 对应包导航 |
| 定位受影响回归 | [test/AGENTS](../test/AGENTS.md) |

本轮范围、依赖方向与协作方式以 [根规范](../AGENTS.md) 为准；尺寸目标见 [UI 规格](../doc/ui-spec.md)，现有真实登录边界见 [登录说明](../doc/authentication.md)。
