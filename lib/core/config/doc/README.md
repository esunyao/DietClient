# 登录配置装配

将编译期配置转换为通用协议和 Authentik 执行器所需配置，按平台选择回调。公开 example 使用不可连接的服务占位符和空 client ID；本地 .env 通过 --dart-define-from-file 注入。

Web 专用 AUTHENTIK_WEB_REDIRECT_URI 在本地为 http://localhost:7357/auth-callback.html，部署回调需与应用同源。配置键和校验入口见 [auth_config.dart](../auth_config.dart)，无效或缺失配置不应触发登录请求。

[目录导航](../AGENTS.md) · [登录说明](../../../../doc/authentication.md) · [根规范](../../../../AGENTS.md)

`ui_preview_config.dart` 独立提供 `WEB_UI_PREVIEW` 编译开关，默认 false；只有 Web 且显式开启才为 true。它不读取认证配置，不伪造身份、不触发网络；由 app 路由与页面 scope 消费。测试通过纯平台/flag 判定覆盖非 Web 忽略开关。

[api_config.dart](../api_config.dart) 单独校验 API_BASE_URL。此值应为部署网关的 HTTPS 基址，由本地 `.env` 编译注入；拒绝空值、含凭据、查询/片段和 `.invalid` 示例，只有 loopback 开发地址允许 HTTP。固定业务路径相对该基址解析，缺失或无效时资料页显示可重试错误，不发送请求。预览和无会话时不创建业务客户端。Web 部署需服务端允许应用源访问 API，并允许预签名对象存储的 PUT/Content-Type 与头像读取；不通过代理令牌或放宽客户端目的地校验绕过 CORS。
