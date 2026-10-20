# 验证资源

[卡片回归](../app_card_material_test.dart) 聚焦 AppCard 中 ListTile、AppListRow 与 SwitchListTile 的 debug 构建及点击/开关交互，并检查默认、零与自定义内边距、边框内缩和底色。执行：`bash tool/flutter.sh test --no-pub test/app_card_material_test.dart`。

当前登录接入补充配置、门控、取消与内存会话的离线回归测试；协议包和执行器测试位于各包 test 目录。无关 Flutter 计数器模板测试已删除。不扩展完整测试矩阵，功能、视觉与性能由用户验收。

2026-10-20 实际结果：协议包与执行器 24 项离线测试通过，应用登录门控、过期、配置、取消等 6 项离线测试通过，两组命令均退出 0。测试使用替换边界，不连接真实身份提供方；真实登录尚未验证，完整结果见 [根说明](../../README.md)。

[目录导航](../AGENTS.md) · [工具](../../tool/AGENTS.md) · [根规范](../../AGENTS.md)
## Windows 玻璃回归

[glass_backdrop_test.dart](../glass_backdrop_test.dart) 覆盖配置和状态边界，并以标题固定、内容位置保留检查顶部导航覆盖量，不绑定旧 ListView 状态或树结构；真实 shader 渲染、视觉与性能仍由用户验收。

## 响应式布局回归

[ui_layout_test.dart](../ui_layout_test.dart) 使用 430×960 手机、1194×834 平板和 320×720 大字视口，聚焦一级/二级标题对齐、固定标题与底部操作、末项可达、受实际父约束控制的双栏、导航高度/大字增长/选中语义/路由点击，以及个人和机构首页的信息顺序。另用配餐 430、饮食历史 1194、我的 360 与文字缩放 1.3 做三处代表性首帧/短滚动检查，不扩展全页矩阵。补充844×390、键盘底部遮挡200的真实 AppShell 手工记录页，检查84顶部导航避让、字段完整可见与输入、滚动触达并点击保存，以及键盘关闭再打开后的值和焦点；另以无外部控制器的内部 Form 检查1194常规布局与短视口切换时 Form、字段及 Scrollable 状态身份保留，并确认恢复常规高度后标题和 footer 仍固定。页面通过 `demoProvider` 替换实例读取本地演示数据，不连接业务网络，不修改生产登录门控。

可由集成验证统一执行：`bash tool/flutter.sh test --no-pub test/ui_layout_test.dart test/glass_backdrop_test.dart test/app_card_material_test.dart test/authentication_gate_test.dart`。本节说明覆盖范围，不声明命令已经运行或测试通过；实际执行结果记录在[根说明](../../README.md)。这些几何与交互断言不是逐页截图/golden 矩阵，也不代表 Android 真机、视觉还原或性能验收。
