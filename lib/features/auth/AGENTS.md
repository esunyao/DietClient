# 登录与认证辅助流程导航

[根规范](../../../AGENTS.md) · [上级](../AGENTS.md) · [公开概览](doc/README.md) · [展示导航](presentation/AGENTS.md)

- [登录页面](presentation/screens/login_screen.dart)
- [登录应用层](application/AGENTS.md)
- [注册表单](presentation/screens/register_screen.dart)
- [邮箱验证](presentation/screens/verify_email_screen.dart)
- [验证结果](presentation/screens/email_verified_screen.dart)
- [字段与密码可见性](presentation/widgets/auth_field.dart)、[辅助流程展示面板](presentation/widgets/auth_preview_panel.dart)、[未保存返回提示](presentation/widgets/auth_form_guard.dart)

视觉沿用公共字阶、表面、Phosphor 图标与页面标题；真实登录保持独立布局，不使用业务演示标签。presentation 不修改登录执行器、会话门控或权限确认语义。

路由见 [core 路径协议](../../core/presentation/app_routes.dart)，装配见 [app 导航](../../app/AGENTS.md)。
