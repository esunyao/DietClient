# Authentik 执行器导航

[根规范](../../AGENTS.md) · [上级](../AGENTS.md) · [公开概览](doc/README.md)

- [公共导出](lib/diet_auth.dart) → [客户端](lib/src/client.dart) 与 [配置、同意提示、错误类型](lib/src/types.dart)
- 条件导出的执行器：[flow_native.dart](lib/src/flow_native.dart)、[flow_stub.dart](lib/src/flow_stub.dart)
- [流程测试](test/flow_executor_test.dart)、[包依赖](pubspec.yaml)

协议依赖见 [diet_oidc](../diet_oidc/AGENTS.md)，应用控制器见 [auth/application](../../lib/features/auth/application/AGENTS.md)，配置与平台边界见 [登录说明](../../doc/authentication.md)。
