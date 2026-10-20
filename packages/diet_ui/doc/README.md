# 绿色设计系统

以新版 C/B 端样板的浅绿画布、深绿强调和克制实体卡片为基础，提供共享主题、页面、表单外观、状态提示、图表与响应式布局。公开入口为 diet_ui.dart。

导航及浮层玻璃通过 Flutter 绘制；关闭、标准、增强三档及能力回退由共享组件处理。应用偏好由 core 管理。包本身不接入原生权限、网络或业务演示状态。

[包导航](../AGENTS.md) · [库选择](../../../doc/library.md) · [根规范](../../../AGENTS.md)

## 卡片表面

AppCard 以圆角 Material 承载底色与边框，支持 ListTile、AppListRow 和 SwitchListTile 的背景与 ink 交互；保持零阴影、无表面染色及圆角裁剪。padding 仍包含原卡片的额外 1px 边框内缩。聚焦回归见 [卡片测试](../../../test/app_card_material_test.dart)。

## 玻璃效果

GlassBackdrop 将真实 background 与 overlay 分开装配，第三方类型只留在包内。Android Impeller 保持实时镜片；Windows Skia 捕获单次装配的背景，增强且 shader 成功后以 pixelRatio 1、同步 high（约60fps）持续更新。标准、关闭、高对比与减少透明度停止持续捕获；库首次挂载仍可能初始化捕获一次。shader 失败回退磨砂，关闭与无障碍使用实体；Web 保持磨砂。Windows 容器跨档位稳定，保留页面状态。AppPageScope.topInset 默认0，加入 AppPage 列表起始内边距。

## 图标兼容边界

Flutter 3.47 的 IconData 为 final，而 phosphor_flutter 2.1.0 的 Dart 图标类继承 IconData。AppIcons 使用核对过的上游 Regular 字体码点和标准 const IconData；依赖包仍提供字体资源与许可。页面只使用 AppIcons，不直接导入旧图标类，不修改依赖缓存。
