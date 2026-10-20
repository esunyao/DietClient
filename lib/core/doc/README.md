# Core

提供统一路由路径及 Riverpod UI 偏好，包含玻璃模式、减少透明度和减少动态。偏好仅保留内存，系统无障碍设置拥有优先级。

共享视觉实现位于 diet_ui，core 原主题和组件路径是薄导出。业务展示模型位于 diet_models，业务演示状态位于 demo。

登录接入由 config 装配编译配置、session 保留内存会话；会话与业务 demo 状态独立，不进行刷新或持久化。流程及验证状态见 [登录说明](../../../doc/authentication.md)。

[导航](../AGENTS.md) · [根规范](../../../AGENTS.md)

config 另提供默认关闭且仅 Web 生效的 WEB_UI_PREVIEW 展示开关；其值独立于内存登录会话，详见 [配置概览](../config/doc/README.md)。

资料业务请求使用独立的 [network](../network/AGENTS.md)；共享真实姓名、邮箱与头像见 [account_identity](../presentation/account_identity.dart)，与预览演示身份分开。登录 Cookie 客户端不承载资料请求。
