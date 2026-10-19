# Windows 宿主

承载 Flutter 演示页面及响应式布局。演示状态仅在内存，不迁移 RN 原生玻璃、真实认证、文件采集或权限流程。共享展示包负责玻璃效果及能力回退。

仓库根目录构建入口为 `bash tool/flutter.sh build windows --debug --no-pub`，需要可用的 Windows 桌面构建工具链。环境与实际结果见 [根说明](../../README.md)、[构建导航](../../tool/AGENTS.md)。本说明不代表已编译或完成桌面验收。

[宿主导航](../AGENTS.md) · [根规范](../../AGENTS.md)
