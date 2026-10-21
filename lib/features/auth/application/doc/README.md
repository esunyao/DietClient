# 登录与邮件控制

LoginController 通过既有 AuthGateway 组合配置、执行器与安全会话；登录默认 `rememberMe=false`，等待 `SessionController.establish` 完成，并保留取消与同意反馈。Web 弹窗不保存原生续期凭据。

AuxiliaryController 通过独立的 AuxiliaryGateway 创建每次注册/重发的短会话，防重复提交，以尝试标识丢弃取消后的旧响应；单次返回值决定该次页面导航。重发只在受理后启动 60 秒冷却，失败保留邮箱并回写字段错误。网页验证不构造登录状态。

[目录导航](../AGENTS.md) · [登录说明](../../../../../doc/authentication.md) · [根规范](../../../../../AGENTS.md)
