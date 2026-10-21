# Core 导航

[根规范](../../AGENTS.md) · [上级](../AGENTS.md) · [说明](doc/README.md)

路径协议：[app_routes.dart](presentation/app_routes.dart)。UI 偏好：[ui_preferences.dart](presentation/ui_preferences.dart)。演示业务状态见 [demo](../demo/AGENTS.md)，路由注册见 [app](../app/AGENTS.md)。

真实登录接入：[config](config/AGENTS.md) → [session](session/AGENTS.md)。跨平台流程见 [登录说明](../../doc/authentication.md)。

主题、组件、布局、图表与玻璃的唯一实现位于 [diet_ui](../../packages/diet_ui/AGENTS.md)。core/theme 和 core/widgets 只保留兼容导出。

Web 预览开关：[ui_preview_config.dart](config/ui_preview_config.dart)，不建立登录身份。

业务请求：[network/AGENTS](network/AGENTS.md)；共享真实身份与头像：[account_identity.dart](presentation/account_identity.dart)，供 app/home/profile 复用。

真实膳食：[nutrition/AGENTS](nutrition/AGENTS.md)；图片选择与恢复：[media/AGENTS](media/AGENTS.md)；跨页面 AI 同意：[privacy/AGENTS](privacy/AGENTS.md)。上述业务适配不放入 diet_ui，feature 不横向导入。
