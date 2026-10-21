# 登录接入

应用保留 Authentik/OIDC 登录，并扩展 Android/Windows 注册、邮件重发、会话刷新及可选记住登录。资料与餐食使用独立业务客户端；无接口能力显示暂未支持。Web 新功能留待下轮，保持原登录、资料和独立预览。MFA、全局 SSO 注销与推送不在本轮范围。

## 包与应用边界

| 位置 | 职责 |
|---|---|
| [diet_oidc](../packages/diet_oidc/AGENTS.md) | 纯 Dart 通用 discovery、PKCE S256、state/nonce、授权码交换、ID Token/JWKS 校验；条件导出的 Web popup 与 BroadcastChannel |
| [diet_auth](../packages/diet_auth/AGENTS.md) | 纯 Dart Authentik Flow Executor、Dio 内存 Cookie；依赖 diet_oidc |
| [core/config](../lib/core/config/AGENTS.md) | 将编译配置装配为包配置，按平台选择回调 |
| [core/session](../lib/core/session/AGENTS.md) | 已验证内存会话、单次并发刷新、启动恢复和系统安全存储适配 |
| [auth/application](../lib/features/auth/application/AGENTS.md) | 控制登录、同意提示、取消和错误反馈 |
| auth/presentation | 绿色登录与注册表单、邮件重发、默认关闭的记住登录；Web 保持原边界 |

通用 OIDC 包不依赖 Authentik、Flutter、Riverpod 或 Cookie。Authentik 包不依赖 Flutter/Riverpod。业务 demoProvider 不承载真实会话。

Android 为优先目标，Windows 复用账号密码直连；无需原生桥接或 WebView。直连执行器仅处理账号密码、autosubmit、user-login 和 consent，未知阶段显式报错。需要 MFA 或其他未支持阶段时不能假装已登录。

Web 使用弹窗访问身份提供方，经 [静态回调](../web/auth-callback.html) 与 [BroadcastChannel 脚本](../web/auth-callback.js) 完成同源通信。回调清除地址栏参数后在内存中发送，主页面校验来源、state 和精确回调 URI。参数与 Token 不写浏览器存储、磁盘或应用日志；取消及事务失败会结束本次尝试，旧结果不建立会话。

弹窗桥接不依赖 opener 或 window.closed，以适应 COOP 隔离。用户关闭弹窗后，主页面仍可能等待，需要点击取消或等待五分钟超时；不承诺即时检测关闭。开始发现身份提供方前已同步打开空白弹窗，避免等待网络后失去用户点击激活。

协议客户端只复用 openid_client 的 PKCE Flow 与令牌模型；授权码交换使用受约束 HTTP 表单，避免调用会在 Fine 日志记录原始响应的 Flow.callback。discovery、Token 和 JWKS 端点受同源 HTTPS 约束，不自动跟随重定向；验签后再校验 claims、nonce 和有效时间。具体算法与字段检查见 [协议源码](../packages/diet_oidc/lib/src/client.dart)。

## 本地配置

公开 [.env.example](../.env.example) 仅包含不可连接的服务占位符和空 client ID；复制为被忽略的本地 `.env` 后配置真实环境，通过 `--dart-define-from-file=.env` 注入。编译配置会进入客户端产物，不放置客户端密钥或服务端凭据。

| 配置键 | 登录用途 |
|---|---|
| AUTHENTIK_BASE_URL | 身份提供方根地址 |
| AUTHENTIK_PROVIDER_SLUG | 组成 discovery 路径 |
| AUTHENTIK_AUTHENTICATION_FLOW_SLUG | 原生账号密码执行器的流程 |
| AUTHENTIK_ENROLLMENT_FLOW_SLUG | Android/Windows 注册流程 |
| AUTHENTIK_EMAIL_VERIFICATION_RESEND_FLOW_SLUG | Android/Windows 邮件重发流程 |
| AUTHENTIK_CLIENT_ID | 公开客户端 ID，example 留空 |
| AUTHENTIK_REDIRECT_URI | Android/Windows 授权响应目标 |
| AUTHENTIK_WEB_REDIRECT_URI | Web 同源静态回调 |
| AUTHENTIK_SCOPES | 空格分隔，必须含 openid |

Android/Windows 请求 offline_access，部署方也需在 Authentik provider 中启用对应 scope mapping；未返回 refresh_token 时，提示无法自动续期但保留当前有效登录。API_BASE_URL 指向部署网关，业务客户端不复用登录 Cookie。Web 本轮不启用记住登录和新增续期能力。

## Android / Windows 会话与邮件

登录默认不记住，仅在内存续期。用户勾选后，刷新令牌及必要身份校验上下文写入系统安全存储，并绑定当前身份提供方、客户端与 API 配置；不保存密码、业务健康资料、图片或签名 URL。普通偏好库仅保存外观。Android 关闭应用自动备份以避免安全存储密钥与密文错配，不调整 SDK。

启动恢复成功前使用独立恢复页，失败可重试或清除本机记录重新登录。刷新按当前登录实例合并；令牌轮换不重建账户页面，退出/换号才清空旧状态与请求。GET 的 401 至多续期重试一次，写操作不自动重发。安全存储失败不降级为明文保存；网络错误不冒充续期成功。

注册和重发只在服务端进入有效邮件阶段后确认请求已受理。注册字段错误对应到表单；取消与迟到响应不推进流程。邮件重发仅在请求受理后进入 60 秒冷却，失败保留邮箱；提示受理不保证邮件一定送达。验证链接由邮件网页完成，用户手动返回重新登录；访问结果页面本身不代表验证成功或已登录。未知认证阶段明确报错。当前应用退出清除本机登录信息，不宣称注销其他 SSO 应用。

业务 API_BASE_URL 应设为部署网关 HTTPS 基址，通过同一 `--dart-define-from-file` 注入；`.env.example` 的 `.invalid` 地址只用于构建，不能连接。HTTP 仅允许 loopback 开发地址。客户端按固定路径发送当前会话 Bearer，禁用重定向；无会话或 Web 预览不请求。Web 需部署方为 API 配置应用源、Authorization 与 JSON 请求所需的 CORS，同时为对象存储允许应用源的预签名 PUT、Content-Type 和头像读取。上传客户端独立且不附 Bearer/Cookie；不要将凭据放入 URL 或公开配置。

`AUTHENTIK_WEB_REDIRECT_URI` 是 Web 专用回调配置。本地使用 `http://localhost:7357/auth-callback.html`，启动固定端口：

```bash
bash tool/flutter.sh run -d chrome --web-port 7357 --dart-define-from-file=.env
```

部署时将回调改为与应用相同的 scheme、host、port，并在身份提供方登记对应回调；不要让 SPA 回退规则覆盖 auth-callback.html 和 auth-callback.js。Android/Windows 回调与其他配置键以公开 example 和实际源码为准。

## 既有登录实施与证据状态

以下是前序登录接入的基础验证记录，不代表本轮 UI 已完成或已视觉验收。UI 目标见 [UI 规格](ui-spec.md)，本轮实际验证另记于根说明和交付说明。

2026-10-20，前序登录接入的协议包、执行器与应用集成源码已完成基础验证：依赖解析、65 个 Dart 文件格式检查、4 个 Bash 脚本语法检查及 flutter analyze 均退出 0；24 项协议/执行器和 6 项应用门控、过期、配置、取消离线测试通过。使用 .env.example 的 Web release 与 Windows debug 构建均退出 0，Web 产物包含两个静态回调文件。完整命令和产物见 [根说明](../README.md)。

Android API 36、Build Tools 36.0.0 与 NDK 28.2 的关键文件不完整，预检未通过，未启动 Android 构建、下载或修改 SDK。当时的 Android 预检步骤报告部分完成，SDK 由用户自行管理；该步骤现已移除，Android 改为单独构建。

[.gitignore](../.gitignore) 已忽略 `.env` 与 `.env.*`，单独允许 `.env.example`。client ID 为空，真实登录尚未验证。先前公开探测曾返回 502，该历史记录不代表当前部署状态；离线通过不能证明真实 discovery、授权码交换或浏览器流程已联通。功能和体验仍由用户验收。

[根规范](../AGENTS.md) · [架构](architecture.md) · [认证模块](../lib/features/auth/AGENTS.md) · [共享包](../packages/AGENTS.md)

Web UI 预览例外：只有 Web 构建显式传入 `--dart-define=WEB_UI_PREVIEW=true` 才允许未登录访问业务演示，登录、注册和验证页面转到首页。该开关默认 false，Windows/Android 忽略；不构造认证网关、不调用登录网络、不创建会话或伪造 Token。预览始终显示“Web UI 预览 · 未登录”、隐藏退出，机构隐私遮罩仍可使用。真实认证协议与默认登录门控保持原有行为。运行命令见 [根说明](../README.md)。
