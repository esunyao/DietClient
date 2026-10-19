# Authentik 流程执行器

纯 Dart 包组合通用 diet_oidc 与 Dio 内存 Cookie，实现 Authentik 登录流程执行。不依赖 Flutter/Riverpod，不维护磁盘 Cookie 或持久会话。

本轮支持账号密码、autosubmit、user-login 和 consent；未知阶段显式报错，不迁移 MFA、验证码、注册或邮箱流程。Android/Windows 复用直连，Web 经 OIDC 弹窗和同源回调完成流程，不在浏览器执行原生 Flow Executor。

公开类型为 AuthentikConfig、AuthentikAuthClient、AuthentikConsent 与 AuthFailure；客户端提供 signInWithPassword、signInWithPopup、cancel 和 dispose，并重导出应用需要的 OidcSession。配置从 baseUri 与 providerSlug 组成 discovery 地址，包含原生与 Web 两个回调 URI。完整签名见 [types](../lib/src/types.dart) 与 [client](../lib/src/client.dart)。

consent 将服务端标题及 permissions/additional_permissions 展示给应用，由 onConsent 明确返回是否同意，有挑战 token 时原样回传。内存 Cookie 每笔流程隔离并在结束时清理，重定向不重放携带密码的 POST，异常不回显密码或完整服务端响应。取消和超时结束当前流程；目前真实联通尚未验证。

[包导航](../AGENTS.md) · [通用 OIDC](../../diet_oidc/AGENTS.md) · [根规范](../../../AGENTS.md)
