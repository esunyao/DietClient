# 共享膳食数据导航

[根规范](../../../../AGENTS.md) · [上级](../AGENTS.md) · [概览](../doc/README.md)

- [nutri_models.dart](nutri_models.dart)：公开接口响应与输入，保留精确字符串 ID；采集响应接收时间用于预览签名 TTL。
- [nutri_api.dart](nutri_api.dart)：公开用户 API 与对象上传。
- [meal_photo.dart](meal_photo.dart)：MealPhoto 与只读 MealPhotoSet；不包含磁盘缓存或业务演示值。
- [共享查询](../application/AGENTS.md)；HTTP 字段以公开后端契约和当前模型为准。
