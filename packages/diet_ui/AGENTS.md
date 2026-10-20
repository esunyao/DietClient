# 设计系统导航

[根规范](../../AGENTS.md) · [上级](../AGENTS.md) · [公开概览](doc/README.md)

- [导出入口](lib/diet_ui.dart)、[主题](lib/src/theme/)
- [控件](lib/src/widgets/)：页面、卡片、按钮、列表、图表、玻璃与布局
- [AppCard](lib/src/widgets/primitives.dart)：卡片 Material 表面与圆角边框；交互和内边距回归见 [卡片测试](../../test/app_card_material_test.dart)
- [包声明](pubspec.yaml)、[Phosphor 许可](PHOSPHOR-LICENSE.txt)
- 应用展示偏好入口：[core](../../lib/core/AGENTS.md)

库选型与来源见 [library](../../doc/library.md)。

- [玻璃背景](lib/src/widgets/glass_backdrop.dart) / [镜片](lib/src/widgets/glass_surface.dart)：平台后端与能力回退；[页面](lib/src/widgets/app_page.dart) 接收导航顶部覆盖量。[聚焦回归](../../test/glass_backdrop_test.dart)。
