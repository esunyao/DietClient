# 工具导航

[根规范与上级](../AGENTS.md) · [公开概览](doc/README.md) · [验证资源](../test/AGENTS.md) · [项目说明](../doc/README.md)

- [flutter.sh](flutter.sh)：将 Pub 缓存和工具临时目录指向本仓库，转发 Flutter 命令。
- [flutter.ps1](flutter.ps1)：PowerShell 等价入口，使用 PATH 中的 Flutter，转发参数及退出码，结束后恢复工作目录和环境变量。
- [activate.ps1](activate.ps1)：点源激活当前 PowerShell 会话，使用项目内缓存与临时目录；已初始化 oh-my-posh 时融入主题色块，否则显示 `(DietClient)`；`deactivate` 恢复原环境与提示符，用法见公开概览。
- [dart.sh](dart.sh)：使用同一 Flutter SDK 的 Dart 工具与仓库内缓存。
- [verify.sh](verify.sh)：格式、分析、离线测试及 Web/Windows 示例编译，Android 单独构建；执行范围以当前脚本和 [根说明](../README.md) 为准。

- [换行规则](../.gitattributes)：`*.sh` 固定 LF；Bash 环境无法执行 Windows SDK 时使用 `flutter.ps1`。
