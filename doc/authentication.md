# 登录接入

本轮仅将登录从界面演示扩展为真实 Authentik/OIDC 流程。应用启动先登录，登录后的膳食、画像、机构、报告和 AI 授权页面继续使用共享内存样例。注册、邮箱验证、MFA、业务 API、Token 刷新与持久化不在本轮范围。

## 包与应用边界

| 位置 | 职责 |
|---|---|
| diet_oidc | 纯 Dart 通用 discovery、PKCE S256、state/nonce、授权码交换、ID Token/JWKS 校验；条件导出的 Web popup 与 BroadcastChannel |
| diet_auth | 纯 Dart Authentik Flow Executor、Dio 内存 Cookie；依赖 diet_oidc |
| core/config | 将编译配置装配为包配置，按平台选择回调 |
| core/session | 仅驻留内存的已验证登录会话 |
| auth/application | 控制登录、同意提示、取消和错误反馈 |
| auth/presentation | 复用绿色表单；注册与邮件页保留演示说明 |

通用 OIDC 包不依赖 Authentik、Flutter、Riverpod 或 Cookie。Authentik 包不依赖 Flutter/Riverpod。业务 demoProvider 不承载真实会话。

Android 为优先目标，Windows 复用账号密码直连；无需原生桥接或 WebView。直连执行器仅处理账号密码、autosubmit、user-login 和 consent，未知阶段显式报错。需要 MFA 或其他未支持阶段时不能假装已登录。

Web 使用弹窗访问身份提供方，经同源静态回调完成通信。回调参数与 Token 不写浏览器存储、磁盘或日志。取消、关闭弹窗和事务失败均需结束当前尝试，不能混入另一笔登录事务。

## 本地配置

公开 `.env.example` 仅包含不可连接的服务占位符和空 client ID；复制为被忽略的本地 `.env` 后配置真实环境，通过 `--dart-define-from-file=.env` 注入。编译配置会进入客户端产物，不放置客户端密钥或服务端凭据。

`AUTHENTIK_WEB_REDIRECT_URI` 是 Web 专用回调配置。本地使用 `http://localhost:7357/auth-callback.html`，启动固定端口：

```bash
bash tool/flutter.sh run -d chrome --web-port 7357 --dart-define-from-file=.env
```

部署时将回调改为与应用相同的 scheme、host、port，并在身份提供方登记对应回调。Android/Windows 回调与其他配置键以公开 example 和实际源码为准。

## 实施与证据状态

登录代码按目录规划接入中，实际接口签名以最终源码为准。配置集成待落实 `.env`、`.env.*` 的忽略规则，并单独允许 `.env.example`；此项由集成阶段更新 .gitignore。当前已知公开探测返回 502，尚未验证真实登录；不能据此判断 discovery、授权码交换、签名校验或平台流程已可用。基础静态检查、各平台编译与真实登录结果分别记录，功能和体验由用户验收，SDK 由用户自行管理。

[根规范](../AGENTS.md) · [架构](architecture.md) · [认证模块](../lib/features/auth/AGENTS.md) · [共享包](../packages/AGENTS.md)
