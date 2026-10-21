# Authentik 流程执行器

纯 Dart 包组合通用 diet_oidc 与 Dio 内存 Cookie。不依赖 Flutter/Riverpod，不保存磁盘 Cookie 或持久会话。账号密码登录、同意和 Web OIDC 弹窗保持既有边界；未知阶段显式失败。

`AuxiliaryFlowExecutor` 提供单次隔离的注册与邮件重发。GET 开始，POST 按已知 prompt 字段或 identification/autosubmit 推进，维护内存 Cookie、CSRF 与 flow id。只向配置的同源 executor 发请求，禁用跳转，不重放凭据；不支持的阶段、重复挑战、超过 12 步或时间限制停止。只有 HTTP 成功的 `ak-stage-email` 且无响应错误和流程错误消息才确认请求受理。EmailChallenge 不要求返回邮箱字段；`email-sent` 响应错误也不当作成功。流程错误在任意阶段停止；受理不保证邮箱存在或邮件送达。

配置的 enrollmentFlowSlug / emailVerificationResendFlowSlug 可缺省，辅助流程开始时校验 slug，不影响既有登录配置。注册返回字段错误 `AuthFieldFailure`；取消关闭请求，dispose 清理 Cookie。邮件验证在网页完成，执行器不交换注册 Token、不建立登录会话、不确认邮箱已验证。

协议依据：[Authentik Flow Executor](https://api.goauthentik.io/flow-executor/)、[官方 EmailChallenge](https://github.com/goauthentik/authentik/blob/main/authentik/stages/email/stage.py)。离线辅助回归在应用 [auth_auxiliary_functional_test.dart](../../../test/auth_auxiliary_functional_test.dart)，登录回归见包内 test；真实服务与邮件未在离线测试中验收。

[包导航](../AGENTS.md) · [通用 OIDC](../../diet_oidc/AGENTS.md) · [根规范](../../../AGENTS.md)
