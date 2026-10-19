# 登录配置装配

将编译期配置转换为通用协议和 Authentik 执行器所需配置，按平台选择回调。公开 example 使用不可连接的服务占位符和空 client ID；本地 .env 通过 --dart-define-from-file 注入。

Web 专用 AUTHENTIK_WEB_REDIRECT_URI 在本地为 http://localhost:7357/auth-callback.html，部署回调需与应用同源。配置键和校验入口见 [auth_config.dart](../auth_config.dart)，无效或缺失配置不应触发登录请求。

[目录导航](../AGENTS.md) · [登录说明](../../../../doc/authentication.md) · [根规范](../../../../AGENTS.md)
