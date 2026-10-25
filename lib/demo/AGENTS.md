# 演示状态导航

[根规范](../../AGENTS.md) · [上级](../AGENTS.md) · [公开概览](doc/README.md)

- [demo_store.dart](demo_store.dart)：共享内存快照、修改入口与跨页统计
- [demo_fixtures.dart](demo_fixtures.dart)：餐食、配餐、健康记录等统一样例
- [demo_nutrition_targets.dart](demo_nutrition_targets.dart)：个人首页只读 UI 演示目标
- [共享模型](../../packages/diet_models/AGENTS.md)、[功能页面](../features/AGENTS.md)

真实模式和隐私遮罩不再由 demo_store 承担，入口见 [display_state](../core/presentation/display_state.dart)；演示模式仍保留独立的样例切换和重置。
