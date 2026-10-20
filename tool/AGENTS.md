# 工具导航

[根规范与上级](../AGENTS.md) · [公开概览](doc/README.md) · [验证资源](../test/AGENTS.md) · [项目说明](../doc/README.md)

- [flutter.sh](flutter.sh)：将 Pub 缓存和工具临时目录指向本仓库，转发 Flutter 命令。
- [flutter.ps1](flutter.ps1)：PowerShell 等价入口，使用 PATH 中的 Flutter，转发参数及退出码，结束后恢复工作目录和环境变量。
- [dart.sh](dart.sh)：使用同一 Flutter SDK 的 Dart 工具与仓库内缓存。
- [android-ready.sh](android-ready.sh)：只检查本机 Android 构建条件，不安装 SDK。
- [verify.sh](verify.sh)：基础验证入口，执行范围以当前脚本和 [根说明](../README.md) 为准。
