# 会话与恢复导航

[根规范](../../../AGENTS.md) · [上级](../AGENTS.md) · [公开概览](doc/README.md)

[session_controller.dart](session_controller.dart) 管理稳定登录代次、恢复状态、续期合并及系统安全存储适配，由 [auth/application](../../features/auth/application/AGENTS.md) 使用。协议与刷新身份类型见 [diet_oidc](../../../packages/diet_oidc/AGENTS.md)；启动恢复页见 [app](../../app/AGENTS.md)，业务请求见 [network](../network/AGENTS.md)。业务演示数据独立位于 [demo](../../demo/AGENTS.md)。
