# 个人资料导航

[根规范](../../../AGENTS.md) · [上级](../AGENTS.md) · [公开概览](doc/README.md) · [展示导航](presentation/AGENTS.md)

- [我的](presentation/screens/profile_screen.dart)：身份、快捷入口、基础资料、健康摘要与机构服务；[资料卡片](presentation/widgets/profile_cards.dart)、[服务与退出入口](presentation/widgets/profile_services.dart)
- [编辑基础资料](presentation/screens/edit_profile_screen.dart)
- [健康档案](presentation/screens/health_records_screen.dart)与[可展开类别摘要](presentation/widgets/health_record_category.dart)
- [五类新增表单](presentation/screens/health_record_form_screen.dart)与[类别](presentation/widgets/health_kind.dart)
- [AI 数据与隐私](presentation/screens/ai_nutrition_consent_screen.dart)
- [未保存返回提示](presentation/widgets/unsaved_form.dart)

编辑基础资料与新增健康记录的公开入口先选择真实或私有演示页，再初始化表单状态。入口隔离回归见 [entry_gateway_test.dart](../../../test/entry_gateway_test.dart)。

跨页演示状态见 [demo store](../../demo/demo_store.dart)，公共模型见 [diet_models](../../../packages/diet_models/lib/diet_models.dart)。设置与路由由 [app](../../app/AGENTS.md) 装配。

真实数据入口：[data](data/AGENTS.md) → [application](application/AGENTS.md) → presentation/screens/real_* 页面。
Web 预览保留原演示页面，真实页面不回退样例。姓名只读；头像使用 [头像编辑](presentation/widgets/avatar_editor.dart) 与 diet_ui 方形裁剪组件。

未登录 Web 预览通过 AppPageScope.uiPreview 隐藏退出入口。真实模式的 [服务入口](presentation/widgets/profile_services.dart) 区分真实饮食记录和暂未支持的报告/机构能力，不展示虚构成员身份；退出范围见 [会话](../../core/session/AGENTS.md)。

[未保存保护兼容入口](presentation/widgets/unsaved_form.dart) 转出 [core 共享保护](../../core/presentation/unsaved_form.dart)，资料与健康表单传入保存中状态，路由切换和返回采用一致的离开检查。真实遮罩使用 [display_state](../../core/presentation/display_state.dart)。
