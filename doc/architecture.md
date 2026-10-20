# 架构

单应用按功能分层，Dart Pub workspace 管理 diet_models、diet_ui、diet_oidc 和 diet_auth。app 负责启动登录门控、路由和外壳，core 提供配置装配、内存会话、路径协议与展示偏好，demo 持有共享业务演示场景，feature 组合页面；feature 不相互导入。

diet_models 只定义营养、餐食、来源、覆盖和报告等展示模型；diet_ui 封装主题、组件、响应式布局、玻璃、图表与本地插画。diet_oidc 提供通用协议与 Web 弹窗通信；diet_auth 依赖 diet_oidc，执行 Authentik 流程及 Dio 内存 Cookie 管理。四个 package 均不依赖应用；协议包不引入 Flutter 或 Riverpod。

既有导航外壳位于 app：840 以下使用四项手机悬浮底栏，Windows/Web 宽屏使用96/216覆盖侧栏并固定预留120正文空间，其他平台宽屏使用顶部导航；个人/机构模式显式选择，不由窗口宽度推断。

本轮校准目标是固定 header、业务独立滚动、安全区单次消费，并按实际父级可用宽度启用适用双栏，保持原 1024 窗口语义的可用宽度等价。手机/平板几何与字阶详见 [UI 规格](ui-spec.md)。这些是本轮目标，不代表所有页面已完成或已视觉验收；实际检查与未完成项在 [根说明](../README.md) 和交付说明另记。

餐食、计划、机构与报告演示统一由 demo store 驱动。我的个人资料、头像、五类健康记录和 AI 同意接入 Orion：core/network 提供独立 Dio 薄客户端，profile/data 与 application 管理接口和异步状态，不创建空 domain 层。共享真实姓名/邮箱/头像放 core/presentation，app/home 不横向导入 profile。真实资料不回退演示；Web 预览保持零会话零业务请求。登录会话只保留内存，不刷新或持久化，退出或切换账户丢弃旧请求结果。平台和配置边界见 [登录说明](authentication.md)。

导航：[lib](../lib/AGENTS.md) → [app](../lib/app/AGENTS.md)、[core](../lib/core/AGENTS.md)、[demo](../lib/demo/AGENTS.md)、[features](../lib/features/AGENTS.md)、[packages](../packages/AGENTS.md)。

Web 构建可显式启用默认关闭的 WEB_UI_PREVIEW；core/config 提供纯平台与标志判定，app 负责路由例外、未登录标识和隐藏退出。预览与会话完全独立，不构造认证网关，非 Web 平台忽略此开关。
