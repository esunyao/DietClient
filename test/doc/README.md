# 验证资源

[卡片回归](../app_card_material_test.dart) 聚焦 AppCard 中 ListTile、AppListRow 与 SwitchListTile 的 debug 构建及点击/开关交互，并检查默认、零与自定义内边距、边框内缩和底色。执行：`bash tool/flutter.sh test --no-pub test/app_card_material_test.dart`。

当前登录接入补充配置、门控、取消与内存会话的离线回归测试；协议包和执行器测试位于各包 test 目录。无关 Flutter 计数器模板测试已删除。不扩展完整测试矩阵，功能、视觉与性能由用户验收。

2026-10-20 实际结果：协议包与执行器 24 项离线测试通过，应用登录门控、过期、配置、取消等 6 项离线测试通过，两组命令均退出 0。测试使用替换边界，不连接真实身份提供方；真实登录尚未验证，完整结果见 [根说明](../../README.md)。

[目录导航](../AGENTS.md) · [工具](../../tool/AGENTS.md) · [根规范](../../AGENTS.md)
