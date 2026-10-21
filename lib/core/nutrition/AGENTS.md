# 共享膳食能力导航

[根规范](../../../AGENTS.md) · [Core](../AGENTS.md) · [概览](doc/README.md)

- [契约模型](data/nutri_models.dart)：采集、餐食、营养汇总及修正输入，精确字符串 ID。
- [API](data/nutri_api.dart)：只调用公开 NutriMemo 用户接口，不接入内部 M2M。
- [共享查询](application/nutrition_providers.dart)：策略、草稿、餐食和汇总 Provider、时区及集中失效刷新。
- 调用方：[采集](../../features/meal_record/AGENTS.md)、[餐食](../../features/meal/AGENTS.md)、[首页](../../features/home/AGENTS.md)、[趋势](../../features/trend/AGENTS.md)。
- 跨层边界：[网络](../network/AGENTS.md)、[会话](../session/AGENTS.md)、[图片](../media/AGENTS.md)、[AI 同意](../privacy/AGENTS.md)。

本层只导航；公开契约以只读 HealthServer/NutriMemo/openapi.yaml 和当前源码为准。
