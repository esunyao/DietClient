# 本地工具

flutter.sh 与 dart.sh 使用同一 SDK，将缓存与临时目录指向仓库内。verify.sh 执行格式、静态检查、协议包与应用门控的离线测试，以及 Web/Windows 编译；构建注入 .env.example 占位配置，不请求真实登录服务。当前执行内容以脚本为准，命令及实际结果由根说明记录。

PowerShell 可使用 `./tool/flutter.ps1` 替代 `bash tool/flutter.sh`，例如 `./tool/flutter.ps1 build windows --release --dart-define-from-file=.env`。该入口使用 PATH 中已有的 Flutter，将参数和原始退出码转交；Pub、Gradle 和临时目录仍隔离在项目内，执行结束后恢复调用者的目录与环境变量，不自动读取 `.env` 或安装、切换 SDK。独立调用可写为 `pwsh -NoProfile -File ./tool/flutter.ps1 --version`。

PowerShell 入口已验证现有 SDK 的 `--version`；使用项目内临时替身验证含空格参数、非零退出码 23、项目工作目录和缓存、调用者目录及环境恢复。本次仅验证包装脚本，没有重新编译应用。

需要类似 Python venv 的当前会话环境时，在仓库根目录的 PowerShell 中点源执行：

```powershell
. ./tool/activate.ps1
flutter --version
deactivate
```

已初始化 oh-my-posh 的终端会在当前主题左侧加入绿色 `DietClient` 色块，保留原主题其他段落与提示符引擎；普通 PowerShell 显示 `(DietClient)` 前缀，当前目录保持不变。`PUB_CACHE`、`GRADLE_USER_HOME` 分别指向项目内 `.pub-cache`、`.gradle-cache`，`TMPDIR`、`TMP`、`TEMP` 指向自动创建的 `.local/tmp`；与 `flutter.ps1` 相同，`CI` 与 `FLUTTER_SUPPRESS_ANALYTICS` 为 `true`。七项设置仅影响当前进程及之后启动的子进程；`deactivate` 恢复激活前的环境变量、提示符和原有同名函数（若有）。重复点源不会叠加前缀或覆盖首次快照。

oh-my-posh 集成使用官方 `config export` 和 `init pwsh --config` 接口，将临时主题存入被忽略的 `.local/tmp/dietclient-*.omp.json`，退出时恢复原主题并删除本次临时文件，不修改用户配置文件或原主题。导出或初始化失败时提示并回退普通前缀。强制关闭终端可能留下临时主题文件，不影响原主题；它们不会提交。主题机制见 [官方自定义说明](https://ohmyposh.dev/docs/installation/customize)。

从其他目录激活时使用该脚本的绝对路径。直接运行 `./tool/activate.ps1` 或 `pwsh -File ./tool/activate.ps1` 只提示必须点源。该入口不永久修改用户或系统环境，不修改 SDK、不读取 `.env`、不自动运行 `pub get`；激活后的 Flutter 使用当前 PATH 中的 SDK。普通单次命令仍可使用 `flutter.ps1`。

激活入口已在 PowerShell 7 验证七项变量、重复激活、普通调用不激活、提示符与原有退出函数恢复、未设置变量恢复及当前目录保持；未重新编译应用。

oh-my-posh 29.26.1 已验证真实主题导出与色块渲染、原引擎保留、重复激活、默认主题及含空格路径的自定义主题恢复和临时文件清理；普通 PowerShell 回退回归通过。

Android 构建由用户通过现有 Flutter 入口单独执行，命令见 [Android 说明](../../android/doc/README.md)。真实登录运行使用被忽略的本地 .env，与离线构建配置分开。

2026-10-20 实际结果：pub get、65 个 Dart 文件格式检查、4 个 Bash 脚本语法检查及 flutter analyze 均退出 0；24 项包测试和 6 项应用离线测试通过；Web release 与 Windows debug 的 example 配置构建退出 0。Android 只读预检未通过，未启动构建或 SDK 下载/修改。命令、缺失组件及产物见 [根说明](../../README.md)。

Android 为优先编译目标，Web/Windows 次之；iOS 不在本轮范围。基础编译不替代用户的功能、视觉或性能验收。

[工具导航](../AGENTS.md) · [运行说明](../../README.md) · [根规范](../../AGENTS.md)

Bash 脚本在 `.gitattributes` 中固定 `*.sh text eol=lf`，仓库内 `tool/*.sh` 使用 LF，避免 Windows 检出后的 CRLF 被 Bash 当成命令字符。若终端实际进入 Linux 环境而无法执行 Windows Flutter，改用既有 PowerShell 入口调用 Windows SDK。
