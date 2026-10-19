# 通用 OIDC 导航

[根规范](../../AGENTS.md) · [上级](../AGENTS.md) · [公开概览](doc/README.md)

- [公共导出](lib/diet_oidc.dart) → [协议客户端、配置、事务、会话与错误](lib/src/client.dart)
- Web 条件导出：[popup_web.dart](lib/src/popup_web.dart)、[popup_stub.dart](lib/src/popup_stub.dart)
- 应用同源回调：[HTML](../../web/auth-callback.html) 与 [通信脚本](../../web/auth-callback.js)
- [协议测试](test/client_test.dart)、[包依赖](pubspec.yaml)

应用装配见 [core/config](../../lib/core/config/AGENTS.md)，上层执行器见 [diet_auth](../diet_auth/AGENTS.md)，跨平台配置见 [登录说明](../../doc/authentication.md)。
