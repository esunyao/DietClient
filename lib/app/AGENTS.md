# 应用装配导航

[根规范](../../AGENTS.md) · [上级](../AGENTS.md) · [说明](doc/README.md)

- 启动、语言、无障碍与隐私遮罩：[diet_app.dart](diet_app.dart)
- 路由注册、登录门控与未知路径恢复：[router.dart](router.dart)，路径协议见 [core](../core/AGENTS.md)，会话见 [session](../core/session/AGENTS.md)
- 手机四项悬浮导航与宽屏顶部导航：[app_shell.dart](app_shell.dart)
- 具体页面见 [features](../features/AGENTS.md)，共享视觉见 [diet_ui](../../packages/diet_ui/AGENTS.md)
- Windows 浮动导航及真实页面背景：[app_shell.dart](app_shell.dart)；顶部覆盖量通过 AppPageScope.topInset 传给页面，[聚焦回归](../../test/glass_backdrop_test.dart)。
