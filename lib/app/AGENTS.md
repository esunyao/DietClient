# 应用装配导航

[根规范](../../AGENTS.md) · [上级](../AGENTS.md) · [说明](doc/README.md)

- 启动、语言、无障碍与隐私遮罩：[diet_app.dart](diet_app.dart)
- 启动恢复与失败重试：[session_restore_screen.dart](session_restore_screen.dart) → [session](../core/session/AGENTS.md)；站内恢复目标校验在 [router.dart](router.dart)。
- 路由注册、登录门控与未知路径恢复：[router.dart](router.dart)，路径协议见 [core](../core/AGENTS.md)，会话见 [session](../core/session/AGENTS.md)
- 手机悬浮岛、Windows/Web 侧栏与其他平台宽屏横向文字导航：[app_shell.dart](app_shell.dart)；真实姓名/头像来自 [共享身份](../core/presentation/account_identity.dart)，Web 预览使用演示身份，保留设置/个人菜单与当前应用退出
- 具体页面见 [features](../features/AGENTS.md)，共享视觉与导航展示见 [diet_ui](../../packages/diet_ui/AGENTS.md)
- 背景单次装配与导航覆盖量：[app_shell.dart](app_shell.dart) → GlassBackdrop/AppPageScope；安全区由 AppPage 消费，[聚焦回归](../../test/glass_backdrop_test.dart)
- 主体滚动筛选、收起与恢复：[navigation_collapse_controller.dart](navigation_collapse_controller.dart)；[交互回归](../../test/navigation_interaction_test.dart)

- Web 未登录预览开关：[core/config/ui_preview_config.dart](../core/config/ui_preview_config.dart) → [router.dart](router.dart)；预览与侧栏回归：[desktop_sidebar_preview_test.dart](../../test/desktop_sidebar_preview_test.dart)。
- 侧栏账户连续进度装配与菜单实例保持：[app_shell.dart](app_shell.dart) → [展示契约](doc/README.md)；中间帧、长名大字与菜单保持：[desktop_sidebar_motion_test.dart](../../test/desktop_sidebar_motion_test.dart)。

编辑与采集路由的 `onExit` 使用 [共享离开保护](../core/presentation/unsaved_form.dart)，认证门控不受表单阻挡。启动层订阅 [本地日期](../core/presentation/current_date.dart)，恢复前台复核日期与真实营养查询；临时模式和遮罩改由 [display_state](../core/presentation/display_state.dart) 管理。回归：[frontend_navigation_test](../../test/frontend_navigation_test.dart)。

全屏餐食相册由 [router.dart](router.dart) 在 AppShell 外注册，统一认证/恢复门控继续生效；照片路径只传 mealId 和可选 imageId。相册页面见 [餐食导航](../features/meal/AGENTS.md)，路由隔离回归见 [meal_photo_route_test](../../test/meal_photo_route_test.dart)。
