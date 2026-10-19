# 库与封装

依赖解析见 pubspec.lock。本机 Flutter 3.47.7 / Dart 3.13.5；选型核对日期2026-10-20。

| 能力 | 选择 | 封装 |
|---|---|---|
| 路由 | [go_router](https://pub.dev/packages/go_router) 18.1.0 | app/router |
| UI状态 | [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) 3.4.3 | core 与 demo |
| 图表 | [fl_chart](https://pub.dev/packages/fl_chart) 1.2.0 | diet_ui |
| 图标 | [phosphor_flutter](https://pub.dev/packages/phosphor_flutter) 2.1.0 | diet_ui 图标入口 |
| SVG | [flutter_svg](https://pub.dev/packages/flutter_svg) 2.3.0 | 本地原稿插画 |
| 玻璃 | [liquid_glass_easy](https://pub.dev/packages/liquid_glass_easy) 5.0.0 | diet_ui；关闭/标准/增强与能力回退 |

玻璃参考 FlClash 的设置交互，使用 Flutter 绘制，避免原生桥接。标准为轻量磨砂；增强只在支持的渲染器使用折射，Web/Windows回退磨砂；高对比/减少透明度优先实体。仅导航、浮层与必要操作区域使用玻璃。

视觉遵循新版绿色样板；系统中文字体回退，本地矢量插画，Phosphor regular 图标。表单、日期、弹层使用 Flutter 标准组件。共享包提供稳定展示接口，第三方 API 不散布到各 feature。
