# DietClient

HealthServer 膳食应用的 Flutter UI 客户端。四主入口为首页、配餐、趋势、我的；个人/机构体验显式切换，窗口尺寸只决定布局。

界面保留 `20261002ui二次设计` 的绿色 C/B 端样板、手机三快捷与四项导航。当前在已有 UI 校准基础上迁移「我的」真实资料功能，React Native 与 Orion 契约作为只读行为参考。可复核的几何、字阶、安全区和材质目标见 [UI 规格](ui-spec.md)；目标不代表已视觉验收。

已有 Authentik/OIDC 登录、启动门控和内存会话保持不变。个人资料、头像、五类健康档案与 AI 营养同意接入 Orion；姓名只读，真实空数据不回退样例。膳食、机构和报告仍为明确演示，不新增令牌刷新、持久化或 AI 分析请求。Web 显式预览零会话、零业务请求。配置见 [登录说明](authentication.md)，行为见 [资料说明](../lib/features/profile/doc/README.md)。

| 任务 | 入口 |
|---|---|
| 了解规范与源码分层 | [根规范](../AGENTS.md) → [架构](architecture.md) → [源码入口](../lib/AGENTS.md) |
| 校准尺寸和视觉层级 | [UI 规格](ui-spec.md) → [设计系统](../packages/diet_ui/AGENTS.md) |
| 查询依赖、玻璃与平台回退 | [库选择](library.md) → [共享包](../packages/AGENTS.md) |
| 定位页面及演示语义 | [迁移对照](migration.md) → [功能导航](../lib/features/AGENTS.md) → [演示状态](../lib/demo/AGENTS.md) |
| 核对现有认证 | [登录说明](authentication.md) → [认证模块](../lib/features/auth/AGENTS.md) |
| 真实资料、头像与健康档案 | [资料导航](../lib/features/profile/AGENTS.md) → [数据](../lib/features/profile/data/AGENTS.md) → [状态](../lib/features/profile/application/AGENTS.md) |
| 运行、聚焦验证与实际结果 | [根说明](../README.md) → [工具](../tool/AGENTS.md) → [验证资源](../test/AGENTS.md) |
| 理解平台宿主 | [Android](../android/AGENTS.md)、[Web](../web/AGENTS.md)、[Windows](../windows/AGENTS.md) |

私有 `doc-project/` 缺失时，本公开入口可独立使用。Android 构建与真机验证由用户负责，iOS 不在本轮范围；集成阶段只做约定的静态检查、聚焦测试和必要的 Web 或 Windows 编译，不扩展完整平台矩阵。功能、视觉和性能由用户验收，实际执行、失败和跳过项在根说明与交付说明另记。
