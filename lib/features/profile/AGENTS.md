# 个人资料导航

[根规范](../../../AGENTS.md) · [上级](../AGENTS.md) · [公开概览](doc/README.md) · [展示导航](presentation/AGENTS.md)

- [我的](presentation/screens/profile_screen.dart)：身份、快捷入口、基础资料、健康摘要与机构服务；[资料卡片](presentation/widgets/profile_cards.dart)、[服务与退出入口](presentation/widgets/profile_services.dart)
- [编辑基础资料](presentation/screens/edit_profile_screen.dart)
- [健康档案](presentation/screens/health_records_screen.dart)与[可展开类别摘要](presentation/widgets/health_record_category.dart)
- [五类新增表单](presentation/screens/health_record_form_screen.dart)与[类别](presentation/widgets/health_kind.dart)
- [AI 数据与隐私](presentation/screens/ai_nutrition_consent_screen.dart)
- [未保存返回提示](presentation/widgets/unsaved_form.dart)

跨页演示状态见 [demo store](../../demo/demo_store.dart)，公共模型见 [diet_models](../../../packages/diet_models/lib/diet_models.dart)。设置与路由由 [app](../../app/AGENTS.md) 装配。
