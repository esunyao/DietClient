# 架构

单应用按功能分层，Dart Pub workspace 管理 diet_models 与 diet_ui。app 负责路由和外壳，core 提供路径协议与展示偏好，demo 持有共享内存场景，feature 组合页面；feature 不相互导入。

diet_models 只定义营养、餐食、来源、覆盖和报告等展示模型；diet_ui 封装主题、组件、响应式布局、玻璃、图表与本地插画。两个 package 不依赖应用。

手机使用四项悬浮底栏，宽屏使用顶部导航；达到1024逻辑像素后启用适用的双栏，840以下使用底栏。个人/机构模式不由窗口宽度推断。

业务演示状态统一由 demo store 驱动。修正影响单餐、首页、历史、趋势和报告更新提示；计划、机构待确认与分析中记录不混入已知摄入。所有数据重启重置，没有隐式持久化或真实后端。

导航：[lib](../lib/AGENTS.md) → [app](../lib/app/AGENTS.md)、[core](../lib/core/AGENTS.md)、[demo](../lib/demo/AGENTS.md)、[features](../lib/features/AGENTS.md)、[packages](../packages/AGENTS.md)。
