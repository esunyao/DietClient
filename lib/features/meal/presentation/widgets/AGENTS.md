# 餐食展示组件

[根规范](../../../../../AGENTS.md) · [上级](../AGENTS.md) · [模块概览](../../doc/README.md)

- [native_meal_widgets.dart](native_meal_widgets.dart)：真实记录的 96 方形缩略图紧凑行、横向封面卡片、餐次元数据和未知营养展示。
- [meal_photo_widgets.dart](meal_photo_widgets.dart)：mealPhotoContent 按账户代次保留签名刷新中的消费者；照片元数据与字节独立加载、无图、空链接、错误和分别重试；本餐横向缩略图；每个展示实例持有独立 MemoryImage/ResizeImage 缓存键，卸载、字节更新和账户 epoch 变化时仅释放自身键。缩略图及相册均以等比例解码边界限制图片尺寸。
- `mealPhotoPresentationEnabledProvider` 默认只在有真实会话时装配照片查询；无会话旧 UI 替身不新增请求。聚焦 Widget 测试可 override 该展示边界，并替换共享元数据与字节 provider，无需真实服务。
- [meal_widgets.dart](meal_widgets.dart)：原 Web 演示组件，继续使用显式演示模型。

共享真实接口：[meal_photo_providers.dart](../../../../core/nutrition/application/meal_photo_providers.dart)；布局偏好：[ui_preferences.dart](../../../../core/presentation/ui_preferences.dart)；聚焦回归：[meal_photo_widget_test.dart](../../../../../test/meal_photo_widget_test.dart)、[meal_gallery_test.dart](../../../../../test/meal_gallery_test.dart)、[慢刷新集成回归](../../../../../test/meal_photo_refresh_widget_test.dart)。
