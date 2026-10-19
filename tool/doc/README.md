# 本地工具

flutter.sh 与 dart.sh 使用同一 SDK，将缓存与临时目录指向仓库内。verify.sh 执行格式、静态检查、协议包与应用门控的离线测试，以及可用平台编译；构建注入 .env.example 占位配置，不请求真实登录服务。当前执行内容以脚本为准，命令及实际结果由根说明记录。

android-ready.sh 只探测现有 SDK/构建条件，条件缺失时 verify 跳过 Android 编译并说明原因，不自动安装。verify.sh 完成其余平台步骤后以 2 退出，保留部分完成状态，不将全部平台标记为成功。真实登录运行使用被忽略的本地 .env，与离线构建配置分开。

2026-10-20 实际结果：pub get、65 个 Dart 文件格式检查、4 个 Bash 脚本语法检查及 flutter analyze 均退出 0；24 项包测试和 6 项应用离线测试通过；Web release 与 Windows debug 的 example 配置构建退出 0。Android 只读预检未通过，未启动构建或 SDK 下载/修改。命令、缺失组件及产物见 [根说明](../../README.md)。

Android 为优先编译目标，Web/Windows 次之；iOS 不在本轮范围。基础编译不替代用户的功能、视觉或性能验收。

[工具导航](../AGENTS.md) · [运行说明](../../README.md) · [根规范](../../AGENTS.md)
