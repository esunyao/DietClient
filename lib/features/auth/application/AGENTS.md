# 登录应用层导航

[根规范](../../../../AGENTS.md) · [上级](../AGENTS.md) · [公开概览](doc/README.md)

[login_controller.dart](login_controller.dart) 提供登录状态、可替换网关、取消和同意反馈，复用 [登录页面](../presentation/screens/login_screen.dart)，组合 [配置](../../../core/config/AGENTS.md)、[会话](../../../core/session/AGENTS.md) 与 [执行器](../../../../packages/diet_auth/AGENTS.md)。

[auxiliary_controller.dart](auxiliary_controller.dart) 提供注册、邮件重发、取消隔离和受理后冷却；独立网关不改变 AuthGateway 登录契约。
