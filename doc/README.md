# DietClient

HealthServer 膳食应用的 Flutter UI 客户端。四主入口为首页、配餐、趋势、我的；个人/机构体验显式切换，窗口尺寸只决定布局。

当前阶段为全量 UI 校准：以 `20261002ui二次设计` 的 C/B 端最终 SVG、设计说明与用户提供的手机个人首页、平板机构首页目标图为主，新版需求 PPT 补充语义，React Native 只辅助未绘流程。可复核的几何、字阶、安全区和材质目标见 [UI 规格](ui-spec.md)；目标不代表已实现或已视觉验收。

已有 Authentik/OIDC 登录、启动门控和内存会话保持不变，本轮不扩展认证或业务网络能力。膳食、画像、机构、报告和 AI 授权继续使用明确标识的共享内存演示，不新增业务 API、上传、相机、持久化或 AI 服务。现有登录边界与历史验证状态见 [登录说明](authentication.md)。

| 任务 | 入口 |
|---|---|
| 了解规范与源码分层 | [根规范](../AGENTS.md) → [架构](architecture.md) → [源码入口](../lib/AGENTS.md) |
| 校准尺寸和视觉层级 | [UI 规格](ui-spec.md) → [设计系统](../packages/diet_ui/AGENTS.md) |
| 查询依赖、玻璃与平台回退 | [库选择](library.md) → [共享包](../packages/AGENTS.md) |
| 定位页面及演示语义 | [迁移对照](migration.md) → [功能导航](../lib/features/AGENTS.md) → [演示状态](../lib/demo/AGENTS.md) |
| 核对现有认证 | [登录说明](authentication.md) → [认证模块](../lib/features/auth/AGENTS.md) |
| 运行、聚焦验证与实际结果 | [根说明](../README.md) → [工具](../tool/AGENTS.md) → [验证资源](../test/AGENTS.md) |
| 理解平台宿主 | [Android](../android/AGENTS.md)、[Web](../web/AGENTS.md)、[Windows](../windows/AGENTS.md) |

私有 `doc-project/` 缺失时，本公开入口可独立使用。Android 构建与真机验证由用户负责，iOS 不在本轮范围；集成阶段只做约定的静态检查、聚焦测试和必要的 Web 或 Windows 编译，不扩展完整平台矩阵。功能、视觉和性能由用户验收，实际执行、失败和跳过项在根说明与交付说明另记。
