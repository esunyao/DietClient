# 绿色设计系统

以新版 C/B 端样板的浅绿画布、深绿强调和克制实体卡片为基础，提供共享主题、页面、表单外观、状态提示、图表与响应式布局。公开入口为 diet_ui.dart。

导航及浮层玻璃通过 Flutter 绘制；关闭、标准、增强三档及能力回退由共享组件处理。应用偏好由 core 管理。包本身不接入原生权限、网络或业务演示状态。

[包导航](../AGENTS.md) · [库选择](../../../doc/library.md) · [根规范](../../../AGENTS.md)

## 图标兼容边界

Flutter 3.47 的 IconData 为 final，而 phosphor_flutter 2.1.0 的 Dart 图标类继承 IconData。AppIcons 使用核对过的上游 Regular 字体码点和标准 const IconData；依赖包仍提供字体资源与许可。页面只使用 AppIcons，不直接导入旧图标类，不修改依赖缓存。
