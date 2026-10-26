# 共享膳食查询导航

[根规范](../../../../AGENTS.md) · [上级](../AGENTS.md) · [概览](../doc/README.md)

- [nutrition_providers.dart](nutrition_providers.dart)：既有餐食、采集与汇总共享查询，集中业务失效。
- [meal_photo_providers.dart](meal_photo_providers.dart)：照片元数据、精确 ID 字节查询、合并签名刷新与账户代次生命周期；导出照片模型。
- [analysis_polling.dart](analysis_polling.dart)：前台轮询、慢请求保护与页面级受限高度装配。
- [数据模型与接口](../data/AGENTS.md)；[独立对象读取](../../network/AGENTS.md)。
- [照片查询回归](../../../../test/meal_photo_provider_test.dart)：排序、元数据复用、轮询下载隔离、刷新上限、取消与换号迟到拒绝。
