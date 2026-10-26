# 餐食页面入口

[根规范](../../../../../AGENTS.md) · [上级](../AGENTS.md) · [模块概览](../../doc/README.md)

- [meal_history_screen.dart](meal_history_screen.dart)、[meal_detail_screen.dart](meal_detail_screen.dart)、[meal_correction_screen.dart](meal_correction_screen.dart)：原有平台分支入口；Web 保持显式演示业务，不加载真实照片。
- [native_meal_history_screen.dart](native_meal_history_screen.dart)：Android/Windows 服务端筛选、分页与本机布局偏好；轮询包裹 AppPage，餐食为列表直接子项，照片 Consumer 随视口挂载。
- [native_meal_detail_screen.dart](native_meal_detail_screen.dart)：真实营养与餐次操作；本餐照片独立于 AI 分析状态，缩略图传 imageId 进入相册。
- [native_meal_gallery_screen.dart](native_meal_gallery_screen.dart)：独立 Scaffold，由 app 在 Shell 外注册受保护路由；PageView、InteractiveViewer、双击、键盘、无栈返回及减少动态。
- [native_meal_correction_screen.dart](native_meal_correction_screen.dart)：真实修正与未保存保护。

照片数据见 [meal_photo_providers.dart](../../../../core/nutrition/application/meal_photo_providers.dart)，局部展示见 [组件导航](../widgets/AGENTS.md)，路由装配见 [app](../../../../app/AGENTS.md)。聚焦回归：[meal_photo_widget_test.dart](../../../../../test/meal_photo_widget_test.dart)、[meal_gallery_test.dart](../../../../../test/meal_gallery_test.dart)。
