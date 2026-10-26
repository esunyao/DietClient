# 架构

单应用按功能分层，Dart Pub workspace 管理 diet_models、diet_ui、diet_oidc 和 diet_auth。app 负责启动登录门控、路由和外壳，core 提供配置装配、内存会话、路径协议与展示偏好，demo 持有共享业务演示场景，feature 组合页面；feature 不相互导入。

diet_models 只定义营养、餐食、来源、覆盖和报告等展示模型；diet_ui 封装主题、组件、响应式布局、玻璃、图表与本地插画。diet_oidc 提供通用协议与 Web 弹窗通信；diet_auth 依赖 diet_oidc，执行 Authentik 流程及 Dio 内存 Cookie 管理。四个 package 均不依赖应用；协议包不引入 Flutter 或 Riverpod。

既有导航外壳位于 app：840 以下使用四项手机悬浮底栏，Windows/Web 宽屏使用96/216覆盖侧栏并固定预留120正文空间，其他平台宽屏使用顶部导航；个人/机构模式显式选择，不由窗口宽度推断。

本轮校准目标是固定 header、业务独立滚动、安全区单次消费，并按实际父级可用宽度启用适用双栏，保持原 1024 窗口语义的可用宽度等价。手机/平板几何与字阶详见 [UI 规格](ui-spec.md)。这些是本轮目标，不代表所有页面已完成或已视觉验收；实际检查与未完成项在 [根说明](../README.md) 和交付说明另记。

Android/Windows 餐食与营养功能由 core/nutrition 的契约模型、API 和共享查询驱动，采集状态留在 meal_record/application；home/meal/trend 通过共享查询联动，不相互导入。core/media 协调选图和丢失结果，core/privacy 提供跨页面 AI 同意；diet_ui 不承载业务状态。无接口的配餐、报告和机构页面显示暂未支持，Web 的旧演示仍独立由 demo store 驱动。

我的个人资料、头像、五类健康记录接入 Orion：core/network 提供独立 Dio 薄客户端，profile/data 与 application 管理请求，不创建空 domain 层。共享真实姓名/邮箱/头像放 core/presentation；真实资料不回退演示。会话层以稳定登录代次隔离账户，令牌续期不清空查询与编辑状态。安全存储仅在勾选记住登录时保存刷新令牌及校验上下文，普通偏好库只保存外观；Web 不启用本轮会话扩展，预览零会话零业务请求。细节见 [登录说明](authentication.md)。

导航：[lib](../lib/AGENTS.md) → [app](../lib/app/AGENTS.md)、[core](../lib/core/AGENTS.md)、[demo](../lib/demo/AGENTS.md)、[features](../lib/features/AGENTS.md)、[packages](../packages/AGENTS.md)。

Web 构建可显式启用默认关闭的 WEB_UI_PREVIEW；core/config 提供纯平台与标志判定，app 负责路由例外、未登录标识和隐藏退出。预览与会话完全独立，不构造认证网关，非 Web 平台忽略此开关。

真实临时显示状态（模式／遮罩）、本地日期与共享离开保护位于 core/presentation；演示业务仍独立位于 demo。可编辑路由共用离开检查，保存中阻止离开，认证失效优先。真实／演示页面在入口选择实现后再创建各自控制器。AppPage 默认不标记数据来源，演示页面显式声明。

历史餐食照片由 core/nutrition 的照片集合与字节查询统一提供，组合餐食详情和采集会话公开接口；core/network 独立读取预签名对象，不共享业务认证。meal 负责紧凑列表、照片卡片、详情缩略图和相册展示，settings 通过已有外观偏好切换布局。相册路由位于 app 根导航器，沿用认证门控，不显示 AppShell。照片与签名只在账户范围的内存中使用。
