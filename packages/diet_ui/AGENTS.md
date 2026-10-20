# 设计系统导航

[根规范](../../AGENTS.md) · [上级](../AGENTS.md) · [公开概览](doc/README.md)

- [导出入口](lib/diet_ui.dart)；子层阅读入口：[主题导航](lib/src/theme/AGENTS.md)、[控件导航](lib/src/widgets/AGENTS.md)
- [颜色](lib/src/theme/app_colors.dart)、[主题装配](lib/src/theme/app_theme.dart)
- 几何与字阶：[AppLayout](lib/src/theme/app_layout.dart)、[AppTypography](lib/src/theme/app_typography.dart)；目标见 [视觉规格](../../doc/ui-spec.md)
- [页面](lib/src/widgets/app_page.dart)：常规高度固定标题与 footer、短视口合并滚动及一次安全区消费；AppPageScope 仅传导航覆盖量
- [导航展示](lib/src/widgets/app_navigation.dart)：手机胶囊岛、宽屏横向文字 tab，不依赖应用路由
- [布局与列表](lib/src/widgets/layout.dart)：按实际约束的754:352双栏、标准 ListTile 薄封装、本地插画
- [基础控件](lib/src/widgets/primitives.dart)：AppCard Material/padding 契约、可选 radius 与可换行分段控件；[卡片回归](../../test/app_card_material_test.dart)
- [营养图表](lib/src/widgets/nutrition_bar_chart.dart)：fl_chart 薄封装、可选高度/末柱强调/缺失标识；数值不补零
- [玻璃背景](lib/src/widgets/glass_backdrop.dart) / [镜片](lib/src/widgets/glass_surface.dart)：平台后端与能力回退；[聚焦回归](../../test/glass_backdrop_test.dart)
- [图标](lib/src/widgets/app_icons.dart)、[包声明](pubspec.yaml)、[Phosphor 许可](PHOSPHOR-LICENSE.txt)
- 应用展示偏好入口：[core](../../lib/core/AGENTS.md)；导航装配：[app](../../lib/app/AGENTS.md)

库选型与来源见 [library](../../doc/library.md)。
