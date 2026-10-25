# 验证资源导航

[根规范与上级](../AGENTS.md) · [公开概览](doc/README.md) · [构建工具](../tool/AGENTS.md)

- [authentication_gate_test.dart](authentication_gate_test.dart)：应用配置、内存会话、门控与取消的离线回归入口
- [app_card_material_test.dart](app_card_material_test.dart)：共享卡片的列表 Material 背景、点击、开关及内边距回归
- [glass_backdrop_test.dart](glass_backdrop_test.dart)：Windows 捕获配置、禁用和无障碍、背景状态、固定标题覆盖量与导航点击；不代表视觉或性能验收
- [navigation_interaction_test.dart](navigation_interaction_test.dart)：三态、拖动提交/取消、迷你首次展开与键盘、真实 AppShell 滚动和状态保留、营养未知/超额
- [ui_layout_test.dart](ui_layout_test.dart)：430 手机、1194 平板与窄屏大字的一级/二级标题对齐、滚动/固定操作、约束双栏、导航与首页内容顺序回归；另含配餐、历史、我的三处代表性首帧/短滚动，以及844×390横屏键盘下演示手工页可编辑、footer可达与表单状态保留检查
- 协议与执行器测试：[diet_oidc](../packages/diet_oidc/test/client_test.dart)、[diet_auth](../packages/diet_auth/test/flow_executor_test.dart)

测试使用本地替换边界，不代表真实身份提供方联通；执行结果见根说明。

- [unsupported_feature_test.dart](unsupported_feature_test.dart)：真实模式未支持入口不显示虚构数据、不修改演示状态，也不提供模拟写操作。

- [profile_api_test.dart](profile_api_test.dart)：无损 ID、网络目的地、五类 CRUD、头像顺序与认证隔离、同意排序、配置与会话切换。
- [profile_widget_test.dart](profile_widget_test.dart)：真实资料空态、预览零请求、配置错误、保存失败留存、原 ID/编码编辑和裁剪。

实际执行入口与结果见 [根说明](../README.md)，功能、视觉和性能验收由用户进行。

- [desktop_sidebar_preview_test.dart](desktop_sidebar_preview_test.dart)：平台/编译开关、预览首页与深链接、无认证网关构造、隐私遮罩、侧栏定时/反向/键盘/鼠标/触摸/短视口、跨断点状态和图表绘制。
- [desktop_sidebar_motion_test.dart](desktop_sidebar_motion_test.dart)：统一进度同目标去重、反向剩余时长、单图标中间帧、稳定文字槽位与单份语义、途中减少动态，以及真实 AppShell 账户／菜单实例保持、长名大字和短窗口；不代表真实窗口视觉或帧率验收。

## Android / Windows 真实功能回归

- [full_foundation_test.dart](full_foundation_test.dart)：并发刷新、轮换与记住登录、迟到拒绝和换账号隔离、受限请求、无认证上传、精确 ID、媒体恢复与同意读取失败。
- [session_restore_ui_test.dart](session_restore_ui_test.dart)：恢复前零业务装配、失败重试、短视口大字及站内返回目标。
- [meal_capture_functional_test.dart](meal_capture_functional_test.dart)：草稿幂等、图片上传中断与显式重试、删除计数、取消和新鲜同意阻断。
- [meal_functional_test.dart](meal_functional_test.dart)：历史筛选分页、元数据与条目修正、失败保留输入、删除、授权重试、读写后刷新和慢 GET 期间不重复失效。
- [nutrition_functional_test.dart](nutrition_functional_test.dart)：真实首页与趋势、营养未知值、限时前台轮询和换查询后的独立窗口。
- [auth_auxiliary_functional_test.dart](auth_auxiliary_functional_test.dart)：注册邮件阶段、字段错误、取消与迟到结果、重发冷却和记住登录入口。
- [preferences_functional_test.dart](preferences_functional_test.dart)：外观新容器恢复、存储失败与重试、Web 内存边界和仅重置外观。

协议包回归仍从各包导航进入；这些离线回归不证明真实服务、邮件投递、对象存储或真机表现。

[Android 说明](../android/doc/README.md) 提供 release 构建、R8 mapping 核对与真机验收入口。上述存储替身回归不覆盖 Java/Kotlin 混淆结果。

前端审查修正回归：[frontend_navigation_test.dart](frontend_navigation_test.dart) 覆盖真实侧栏离开、保存中返回、无栈操作、认证失效及隔夜恢复；[current_date_test.dart](current_date_test.dart) 覆盖本地午夜与时钟变化；[display_state_test.dart](display_state_test.dart) 确认真实显示与演示隔离；[entry_gateway_test.dart](entry_gateway_test.dart) 确认真实入口不初始化演示状态；[api_error_test.dart](api_error_test.dart) 覆盖安全错误映射；[native_layout_test.dart](native_layout_test.dart) 覆盖真实采集、修正、首页的窄屏、大字和键盘。
