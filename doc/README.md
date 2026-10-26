# DietClient

HealthServer 膳食应用的 Flutter 客户端。四主入口为首页、配餐、趋势、我的；个人/机构体验显式切换，窗口尺寸只决定布局。

界面保留绿色 C/B 端样板、手机快捷入口与四项导航。本轮在「我的」基础上迁移 Android/Windows 剩余真实能力，React Native 与 HealthServer 契约作为只读参考。几何、字阶、安全区和材质目标见 [UI 规格](ui-spec.md)；目标不代表已视觉验收。

真实资料、头像、五类健康档案及 AI 同意由 Orion 提供；采集、餐食和营养汇总由 NutriMemo 提供。注册与邮件重发使用 Authentik；会话增加自动续期和默认关闭的记住登录。未支持的报告、配餐、机构及手工新建不伪造结果。Web 新功能延期，保留既有登录和独立零请求预览。配置见 [认证](authentication.md)，页面能力见 [迁移对照](migration.md)。

| 任务 | 入口 |
|---|---|
| 了解规范与源码分层 | [根规范](../AGENTS.md) → [架构](architecture.md) → [源码入口](../lib/AGENTS.md) |
| 校准尺寸和视觉层级 | [UI 规格](ui-spec.md) → [设计系统](../packages/diet_ui/AGENTS.md) |
| 查询依赖、玻璃与平台回退 | [库选择](library.md) → [共享包](../packages/AGENTS.md) |
| 定位页面及演示语义 | [迁移对照](migration.md) → [功能导航](../lib/features/AGENTS.md) → [演示状态](../lib/demo/AGENTS.md) |
| 核对现有认证 | [登录说明](authentication.md) → [认证模块](../lib/features/auth/AGENTS.md) |
| 历史餐食照片、详情与相册 | [餐食导航](../lib/features/meal/AGENTS.md) → [膳食查询](../lib/core/nutrition/AGENTS.md) → [设置](../lib/features/settings/AGENTS.md) |
| 真实资料、头像与健康档案 | [资料导航](../lib/features/profile/AGENTS.md) → [数据](../lib/features/profile/data/AGENTS.md) → [状态](../lib/features/profile/application/AGENTS.md) |
| 运行、聚焦验证与实际结果 | [根说明](../README.md) → [工具](../tool/AGENTS.md) → [验证资源](../test/AGENTS.md) |
| 理解平台宿主 | [Android](../android/AGENTS.md)、[Web](../web/AGENTS.md)、[Windows](../windows/AGENTS.md) |

私有 `doc-project/` 缺失时，本公开入口可独立使用。历史照片增量的后续测试、Android/Windows 构建与 ADB 真机验收由用户接手，iOS 不在本轮范围；实际结果以根说明记录为准。功能、视觉和性能由用户验收，实际执行、失败和跳过项在根说明与交付说明另记。
