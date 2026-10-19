# 库与封装

选型核对日期 2026-10-20；本机 Flutter 3.47.7 / Dart 3.13.5。pubspec.yaml 声明兼容范围，pubspec.lock 固定应用解析版本。

| 能力 | 选择 | 封装归属 |
|---|---|---|
| 路由与多入口 | [go_router](https://pub.dev/packages/go_router) | app/router，feature 引用统一路径 |
| UI 偏好 | [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) | core/presentation；不承载登录态 |
| 营养图表 | [fl_chart](https://pub.dev/packages/fl_chart) | insights/presentation/widgets，页面不直接依赖图表细节 |
| 线性图标 | [lucide_icons_flutter](https://pub.dev/packages/lucide_icons_flutter) | core/widgets/AppIcons；第三方 Lucide 适配 |
| 表单、分段、日期、浮层 | Flutter Form / Material | core 统一外观，feature 局部交互 |
| 玻璃 | [BackdropFilter](https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html)、ClipRRect | core/GlassSurface，减少透明与高对比回退 |

RN 主色 F2F2F7、FFFFFF、1D1D1F、6E6E73、007AFF；语义色 34C759/FF9500/FF3B30；圆角 12/18/26。系统字体与中文回退，无运行时下载。内容卡为实体表面，仅导航和浮层模糊，尊重系统减少动画。

不引入 HTTP、OAuth、持久化、相机、上传、原生玻璃插件和代码生成器。参考 [Flutter 关注点分离建议](https://docs.flutter.dev/app-architecture/guide)，按实际需要添加数据层和 domain 层。
