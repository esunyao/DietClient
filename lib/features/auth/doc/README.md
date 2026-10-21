# 登录与认证辅助流程

沿用绿色主题、紧凑表单与辅助流程面板。登录继续使用 Authentik/OIDC，经协议校验后建立会话。Android/Windows 的「记住登录」默认不勾选，控制器等待安全会话建立；凭据存储与续期由 core/session 负责。Web 保持原有 SSO 弹窗。

Android/Windows 注册收集用户名、邮箱、密码、确认密码及可选昵称，使用独立内存 Cookie/CSRF 流程，字段错误回到对应表单。只有 HTTP 成功、有效 `ak-stage-email` 且没有响应错误或流程错误才提示需要邮件验证；跳转、未知步骤、无进展及网络结果不明均不声称注册成功。取消与尝试标识隔离旧结果，不自动登录，不模拟验证完成；取消后的旧回调不清空新输入。

验证邮件在网页打开，用户完成后手动返回登录。重发接受有效邮箱，服务受理后冷却 60 秒；失败保留邮箱。受理不保证邮箱存在或邮件送达。配置使用可选的 `enrollmentFlowSlug` 与 `emailVerificationResendFlowSlug`，缺少辅助配置不阻断登录。Web 保留注册/邮件演示，不新增真实注册、邮件或存储能力。

离线回归见 [auth_auxiliary_functional_test.dart](../../../../test/auth_auxiliary_functional_test.dart)。真实身份服务、邮件投递与设备体验仍需环境验收。

[导航](../AGENTS.md) · [登录说明](../../../../doc/authentication.md) · [项目规范](../../../../AGENTS.md)
