# 共享包

Dart Pub workspace 管理展示与登录包：diet_models 提供纯 Dart 展示模型，diet_ui 提供 Flutter 设计系统；新增 diet_oidc 提供通用协议，diet_auth 在其上执行 Authentik 流程。应用业务演示状态由 lib/demo 管理，登录会话由 core/session 保留内存，包不维护应用状态副本。

[共享包导航](../AGENTS.md) · [项目架构](../../doc/architecture.md) · [根规范](../../AGENTS.md)
