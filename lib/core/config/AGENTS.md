# 登录配置导航

[根规范](../../../AGENTS.md) · [上级](../AGENTS.md) · [公开概览](doc/README.md)

[auth_config.dart](auth_config.dart) 装配编译配置，连接 [diet_auth](../../../packages/diet_auth/AGENTS.md) 与 [auth/application](../../features/auth/application/AGENTS.md)。公开键见 [.env.example](../../../.env.example)，环境注入和平台回调见 [登录说明](../../../doc/authentication.md)。

[ui_preview_config.dart](ui_preview_config.dart) 提供纯平台/编译标志判定与 Provider；`WEB_UI_PREVIEW` 默认关闭且只对 Web 生效，路由和 UI 装配见 [app](../../app/AGENTS.md)。

[api_config.dart](api_config.dart) 校验 API_BASE_URL；独立业务客户端见 [network](../network/AGENTS.md)，真实资料入口见 [profile](../../features/profile/AGENTS.md)。
