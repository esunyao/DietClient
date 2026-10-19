# 架构

单应用按功能分层，Dart Pub workspace 管理 diet_models、diet_ui、diet_oidc 和 diet_auth。app 负责启动登录门控、路由和外壳，core 提供配置装配、内存会话、路径协议与展示偏好，demo 持有共享业务演示场景，feature 组合页面；feature 不相互导入。

diet_models 只定义营养、餐食、来源、覆盖和报告等展示模型；diet_ui 封装主题、组件、响应式布局、玻璃、图表与本地插画。diet_oidc 提供通用协议与 Web 弹窗通信；diet_auth 依赖 diet_oidc，执行 Authentik 流程及 Dio 内存 Cookie 管理。四个 package 均不依赖应用；协议包不引入 Flutter 或 Riverpod。

手机使用四项悬浮底栏，宽屏使用顶部导航；达到1024逻辑像素后启用适用的双栏，840以下使用底栏。个人/机构模式不由窗口宽度推断。

业务演示状态统一由 demo store 驱动。修正影响单餐、首页、历史、趋势和报告更新提示；计划、机构待确认与分析中记录不混入已知摄入。业务数据重启重置，没有真实业务后端。登录会话由 core/session 单独保留内存，auth/application 控制流程；不刷新或持久化会话。平台和配置边界见 [登录说明](authentication.md)。

导航：[lib](../lib/AGENTS.md) → [app](../lib/app/AGENTS.md)、[core](../lib/core/AGENTS.md)、[demo](../lib/demo/AGENTS.md)、[features](../lib/features/AGENTS.md)、[packages](../packages/AGENTS.md)。
