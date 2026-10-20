# 共享包导航

[根规范与上级](../AGENTS.md) · [公开概览](doc/README.md) · [应用源码](../lib/AGENTS.md) · [UI 规格](../doc/ui-spec.md)

本层只说明包职责与阅读路径，不新增规范。包不依赖应用；UI 校准主要进入 diet_ui，既有模型与认证包的行为边界保持不变。

| 任务 | 包入口 | 职责与边界 |
|---|---|---|
| 营养、餐食、来源、覆盖与报告展示值 | [diet_models](diet_models/AGENTS.md) | 不依赖 Flutter 的展示模型与数值表达 |
| 绿色主题、字阶、几何、控件、图表与玻璃 | [diet_ui](diet_ui/AGENTS.md) | 设计系统、响应式布局与第三方 UI 薄封装，不持有业务状态 |
| 理解现有 OIDC 协议或 Web 弹窗通信 | [diet_oidc](diet_oidc/AGENTS.md) | 纯 Dart 通用协议，不依赖 Authentik、Flutter、Riverpod 或 Cookie |
| 理解现有 Authentik 登录执行 | [diet_auth](diet_auth/AGENTS.md) | 依赖 diet_oidc 的纯 Dart 流程执行器与内存 Cookie |

工作区入口见 [pubspec.yaml](../pubspec.yaml)，解析版本见 [pubspec.lock](../pubspec.lock)，封装选择见 [library](../doc/library.md)。进入各包导航后再读取其公开 doc、导出入口、实现与回归；认证集成路径见 [authentication](../doc/authentication.md)，视觉目标见 [ui-spec](../doc/ui-spec.md)。
