# 图片选择协调导航

[根规范](../../../AGENTS.md) · [Core](../AGENTS.md) · [概览](doc/README.md)

- [media_coordinator.dart](media_coordinator.dart)：选图用途、账户归属、Android 丢失结果和实际图片检查。
- 头像调用方：[avatar_editor.dart](../../features/profile/presentation/widgets/avatar_editor.dart)；采集调用方：[meal_record](../../features/meal_record/AGENTS.md)。
- 上传隔离：[network](../network/AGENTS.md)；头像专用方形裁剪：[diet_ui](../../../packages/diet_ui/AGENTS.md)。

选择与恢复不等于上传，恢复图片不能跨账户或用途分发。具体行为以源码和模块说明为准。
