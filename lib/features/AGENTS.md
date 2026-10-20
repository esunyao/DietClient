# 功能导航

[根规范](../../AGENTS.md) · [上级](../AGENTS.md) · [公开概览](../../doc/README.md) · [迁移对照](../../doc/migration.md) · [UI 规格](../../doc/ui-spec.md)

本层只导航页面职责，不新增规范。按任务进入目标 feature 的 `AGENTS.md`，再到其 `doc/README.md` 与 `presentation/screens/`；需要本 feature 内部复用时查看其 widgets，不以通读全部页面作为前提。

| 任务 | 模块入口与边界 |
|---|---|
| 手机个人/平板机构首页与快捷入口 | [home](home/AGENTS.md) |
| 示例图片、餐别、备注与记录草稿 | [meal_record](meal_record/AGENTS.md) |
| 历史、详情、修正与手工新建 | [meal](meal/AGENTS.md) |
| 下一餐方案、替换与加入计划 | [meal_plan](meal_plan/AGENTS.md) |
| 周期趋势与逐营养素统计 | [trend](trend/AGENTS.md) |
| 报告预览、版本与更新提示 | [report](report/AGENTS.md) |
| 食堂菜单、机构餐食同步与确认 | [institution](institution/AGENTS.md) |
| 保留现有真实登录，校准注册/邮箱辅助预览 | [auth](auth/AGENTS.md) → [登录说明](../../doc/authentication.md) |
| 个人资料、五类健康记录与授权预览 | [profile](profile/AGENTS.md) |
| 外观、显式体验模式与隐私预览 | [settings](settings/AGENTS.md) |

共享路径、偏好和真实会话见 [core](../core/AGENTS.md)，共享业务内存状态见 [demo](../demo/AGENTS.md)，设计系统见 [packages](../../packages/AGENTS.md)，路由与导航装配见 [app](../app/AGENTS.md)。跨页面数值语义沿 [demo](../demo/AGENTS.md) 核对，不由页面自行复制状态；分层和本轮范围以 [根规范](../../AGENTS.md) 为准。
