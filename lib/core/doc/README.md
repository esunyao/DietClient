# Core

提供统一路由路径及 Riverpod UI 偏好，包含玻璃模式、减少透明度和减少动态。Android/Windows 外观偏好通过普通键值存储保存，系统无障碍设置拥有优先级；不在偏好中保存 Token、健康资料或签名 URL。

共享视觉实现位于 diet_ui，core 原主题和组件路径是薄导出。业务展示模型位于 diet_models，业务演示状态位于 demo。

config 装配编译配置，session 管理已验证会话、自动续期和可选安全存储；稳定登录代次将刷新与退出/换号分开。Web 不启用本轮会话扩展，预览与会话独立。流程及边界见 [登录说明](../../../doc/authentication.md)。

[导航](../AGENTS.md) · [根规范](../../../AGENTS.md)

config 另提供默认关闭且仅 Web 生效的 WEB_UI_PREVIEW 展示开关；其值独立于内存登录会话，详见 [配置概览](../config/doc/README.md)。

资料业务请求使用独立的 [network](../network/AGENTS.md)；共享真实姓名、邮箱与头像见 [account_identity](../presentation/account_identity.dart)，与预览演示身份分开。登录 Cookie 客户端不承载资料请求。

账户名称优先显示去除首尾空白后的 displayName；缺失或为空时显示 username，两者均为空时显示“姓名未提供”。我的页面与侧栏共用此规则。

共享 [nutrition](../nutrition/AGENTS.md) 提供膳食契约与查询，[media](../media/AGENTS.md) 分发选图和恢复结果，[privacy](../privacy/AGENTS.md) 核对真实 AI 同意。具体页面仅组合状态与展示，不复制跨页面网络或账户隔离逻辑。

共享表单保护统一系统返回与路由替换的未保存确认，保存中阻止返回及打开设置；没有返回栈时转往明确的业务目标。真实模式和隐私遮罩只保留于独立 display_state，不修改演示业务。current_date 按下一次本地午夜更新，恢复前台时复核日期；无订阅时停止计时。
