# 内存登录会话

只保留经过协议校验的当前登录会话，供启动门控与应用流程使用。与 demoProvider 的业务样例分开；重启后不自动恢复，不接入 Token 刷新、磁盘或浏览器持久化。

调试输出不显示凭据或 Token。[SessionController](../session_controller.dart) 在会话到期时清理状态，并提供主动检查与清理入口；门控行为和实际平台效果以实施验证为准。

[目录导航](../AGENTS.md) · [登录说明](../../../../doc/authentication.md) · [根规范](../../../../AGENTS.md)
