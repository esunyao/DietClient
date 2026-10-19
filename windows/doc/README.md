# Windows 宿主

承载 Flutter 业务演示页面及响应式布局。真实登录复用 Android 的 Dart 账号密码直连与内存会话，无原生桥接或 WebView；业务状态仍为演示，不接入文件采集或持久化。共享展示包负责玻璃效果及能力回退。

配置和登录验证状态见 [登录说明](../../doc/authentication.md)。

仓库根目录离线构建入口为 `bash tool/flutter.sh build windows --debug --no-pub --dart-define-from-file=.env.example`，需要可用的 Windows 桌面构建工具链。环境与实际结果见 [根说明](../../README.md)、[构建导航](../../tool/AGENTS.md)。

2026-10-20 实际结果：Windows debug 使用 .env.example 编译退出 0，产物为 build/windows/x64/runner/Debug/diet_client.exe。client ID 为空，真实登录及桌面功能、视觉、性能仍未验收。

[宿主导航](../AGENTS.md) · [根规范](../../AGENTS.md)
