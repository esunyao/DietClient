# 本地工具

flutter.sh 与 dart.sh 使用同一 SDK，将缓存与临时目录指向仓库内。verify.sh 执行格式、静态检查、协议包与应用门控的离线测试，以及可用平台编译；构建注入 .env.example 占位配置，不请求真实登录服务。当前执行内容以脚本为准，命令及实际结果由根说明记录。

PowerShell 可使用 `./tool/flutter.ps1` 替代 `bash tool/flutter.sh`，例如 `./tool/flutter.ps1 build windows --release --dart-define-from-file=.env`。该入口使用 PATH 中已有的 Flutter，将参数和原始退出码转交；Pub、Gradle 和临时目录仍隔离在项目内，执行结束后恢复调用者的目录与环境变量，不自动读取 `.env` 或安装、切换 SDK。独立调用可写为 `pwsh -NoProfile -File ./tool/flutter.ps1 --version`。

PowerShell 入口已验证现有 SDK 的 `--version`；使用项目内临时替身验证含空格参数、非零退出码 23、项目工作目录和缓存、调用者目录及环境恢复。本次仅验证包装脚本，没有重新编译应用。

android-ready.sh 只探测现有 SDK/构建条件，条件缺失时 verify 跳过 Android 编译并说明原因，不自动安装。verify.sh 完成其余平台步骤后以 2 退出，保留部分完成状态，不将全部平台标记为成功。真实登录运行使用被忽略的本地 .env，与离线构建配置分开。

2026-10-20 实际结果：pub get、65 个 Dart 文件格式检查、4 个 Bash 脚本语法检查及 flutter analyze 均退出 0；24 项包测试和 6 项应用离线测试通过；Web release 与 Windows debug 的 example 配置构建退出 0。Android 只读预检未通过，未启动构建或 SDK 下载/修改。命令、缺失组件及产物见 [根说明](../../README.md)。

Android 为优先编译目标，Web/Windows 次之；iOS 不在本轮范围。基础编译不替代用户的功能、视觉或性能验收。

[工具导航](../AGENTS.md) · [运行说明](../../README.md) · [根规范](../../AGENTS.md)
