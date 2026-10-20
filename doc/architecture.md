# 架构

单应用按功能分层，Dart Pub workspace 管理 diet_models、diet_ui、diet_oidc 和 diet_auth。app 负责启动登录门控、路由和外壳，core 提供配置装配、内存会话、路径协议与展示偏好，demo 持有共享业务演示场景，feature 组合页面；feature 不相互导入。

diet_models 只定义营养、餐食、来源、覆盖和报告等展示模型；diet_ui 封装主题、组件、响应式布局、玻璃、图表与本地插画。diet_oidc 提供通用协议与 Web 弹窗通信；diet_auth 依赖 diet_oidc，执行 Authentik 流程及 Dio 内存 Cookie 管理。四个 package 均不依赖应用；协议包不引入 Flutter 或 Riverpod。

既有导航外壳位于 app：840 以下使用四项手机悬浮底栏，宽屏使用顶部导航；个人/机构模式显式选择，不由窗口宽度推断。

本轮校准目标是固定 header、业务独立滚动、安全区单次消费，并按实际父级可用宽度启用适用双栏，保持原 1024 窗口语义的可用宽度等价。手机/平板几何与字阶详见 [UI 规格](ui-spec.md)。这些是本轮目标，不代表所有页面已完成或已视觉验收；实际检查与未完成项在 [根说明](../README.md) 和交付说明另记。

业务演示状态统一由 demo store 驱动。修正影响单餐、首页、历史、趋势和报告更新提示；计划、机构待确认与分析中记录不混入已知摄入。业务数据重启重置，没有真实业务后端。登录会话由 core/session 单独保留内存，auth/application 控制流程；不刷新或持久化会话。平台和配置边界见 [登录说明](authentication.md)。

导航：[lib](../lib/AGENTS.md) → [app](../lib/app/AGENTS.md)、[core](../lib/core/AGENTS.md)、[demo](../lib/demo/AGENTS.md)、[features](../lib/features/AGENTS.md)、[packages](../packages/AGENTS.md)。
