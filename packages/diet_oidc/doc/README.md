# 通用 OIDC

纯 Dart 协议包负责 discovery、PKCE S256、state/nonce、授权码交换和 ID Token/JWKS 校验。Web popup 与 BroadcastChannel 通过条件导出封装，通用层不依赖 Authentik、Flutter、Riverpod 或 Cookie。

公开类型为 OidcConfig、OidcClient、OidcTransaction、OidcSession 与 OidcFailure；客户端提供 beginAuthorization、completeAuthorization、signInWithPopup、cancel、cancelPending 和 dispose。cancelPending 也会使仍在等待 discovery 的旧尝试失效。事务一次性使用，expiresAt 为非空值，会话到期取令牌响应与已验证 ID Token 到期时间中较早者；具体实现见 [客户端](../lib/src/client.dart)。

复用 openid_client 的 S256 PKCE Flow 和令牌模型；授权码交换使用受约束 package:http 客户端执行标准表单，不调用会将原始响应写入 Fine 日志的 Flow.callback。JWKS 同样由该受约束 HTTPS 同源客户端取得，签名验证复用 jose，并收集 claims 校验错误，另检查必填字段、nonce、iat 与 nbf。不修改 Pub 缓存或全局日志设置。

事务与会话仅驻留内存，调试字符串脱敏。Web 先在用户点击栈中打开空白弹窗，再发现身份提供方；随机 state 命名的 BroadcastChannel 校验来源和回调，静态页清除地址栏参数后重试发送并等待确认，不通过浏览器存储传递参数或 Token。

为兼容 COOP，不依赖 opener 或 window.closed。用户关闭弹窗后，主页面可显式取消，或等待五分钟事务超时；没有保证即时检测关闭。静态回调的发送确认等待与主登录事务超时分别处理。真实登录尚未验证，源码边界不等同于生产或端到端验收。

[包导航](../AGENTS.md) · [登录说明](../../../doc/authentication.md) · [根规范](../../../AGENTS.md)
