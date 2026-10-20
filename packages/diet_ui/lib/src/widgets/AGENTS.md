# 共享控件导航

[根规范](../../../../../AGENTS.md) · [包导航](../../../AGENTS.md) · [公开概览](../../../doc/README.md)

- [页面](app_page.dart)：常规固定标题与 footer、短视口合并滚动、安全区与应用回调
- [导航展示](app_navigation.dart)：手机悬浮岛、宽屏文字 tab；路由装配见 [app](../../../../../lib/app/AGENTS.md)
- [基础控件](primitives.dart)：Material 卡片、标题、按钮、状态与分段；[卡片回归](../../../../../test/app_card_material_test.dart)
- [列表与布局](layout.dart)：标准 ListTile 薄封装、约束双栏与本地插画
- [图表](nutrition_bar_chart.dart)：fl_chart 薄封装，展示缺失而不补零
- [背景](glass_backdrop.dart) / [镜片](glass_surface.dart)：玻璃三档、平台能力与无障碍回退；[玻璃回归](../../../../../test/glass_backdrop_test.dart)
- [图标](app_icons.dart)：标准 IconData 与已锁定 Phosphor 字库边界
- 几何与字阶入口见 [theme](../theme/AGENTS.md)；[聚焦布局回归](../../../../../test/ui_layout_test.dart)

- 三态连续进度与运动泡手势：[app_navigation.dart](app_navigation.dart) → [glass_surface.dart](glass_surface.dart)；[交互回归](../../../../../test/navigation_interaction_test.dart)

- [侧栏](app_side_navigation.dart)：桌面紧凑导航，单图标与可逆运动进度，复用 GlassSurface；平台断点和连续账户展示由[应用装配](../../../../../lib/app/AGENTS.md)负责。[中间帧回归](../../../../../test/desktop_sidebar_motion_test.dart)。
