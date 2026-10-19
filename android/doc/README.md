# Android 宿主

承载同一套 Flutter 演示界面，Android 为本轮优先编译目标。绿色组件与玻璃由共享 Flutter UI 包绘制，没有迁移 RN 原生玻璃、真实采集或权限流程。

仓库根目录构建入口为 `bash tool/flutter.sh build apk --debug --no-pub`；前置环境和实际结果见 [根说明](../../README.md)、[构建导航](../../tool/AGENTS.md)。本说明不代表已经完成构建或真机验收。

[宿主导航](../AGENTS.md) · [根规范](../../AGENTS.md)
