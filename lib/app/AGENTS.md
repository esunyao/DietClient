# 应用装配导航

[根规范](../../AGENTS.md) · [上级](../AGENTS.md) · [说明](doc/README.md)

- 启动、语言、无障碍与隐私遮罩：[diet_app.dart](diet_app.dart)
- 路由注册、登录门控与未知路径恢复：[router.dart](router.dart)，路径协议见 [core](../core/AGENTS.md)，会话见 [session](../core/session/AGENTS.md)
- 手机悬浮岛、Windows/Web 侧栏与其他平台宽屏横向文字导航：[app_shell.dart](app_shell.dart)；只读取演示身份、保留设置/个人菜单与当前应用退出
- 具体页面见 [features](../features/AGENTS.md)，共享视觉与导航展示见 [diet_ui](../../packages/diet_ui/AGENTS.md)
- 背景单次装配与导航覆盖量：[app_shell.dart](app_shell.dart) → GlassBackdrop/AppPageScope；安全区由 AppPage 消费，[聚焦回归](../../test/glass_backdrop_test.dart)
- 主体滚动筛选、收起与恢复：[navigation_collapse_controller.dart](navigation_collapse_controller.dart)；[交互回归](../../test/navigation_interaction_test.dart)

- Web 未登录预览开关：[core/config/ui_preview_config.dart](../core/config/ui_preview_config.dart) → [router.dart](router.dart)；预览与侧栏回归：[desktop_sidebar_preview_test.dart](../../test/desktop_sidebar_preview_test.dart)。
