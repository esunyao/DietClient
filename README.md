# 膳食健康 DietClient

基于新版绿色 C/B 端样板的 Flutter UI 演示。四个入口为首页、配餐、趋势、我的；个人/机构内个人模式在设置中明确选择，宽度只控制布局。

演示包括记录/草稿、历史、详情与份量修正、配餐计划、机构确认、趋势报告、健康档案及认证辅助流程。共享状态只保留内存，重启或设置内重置恢复初始样例；无真实账户、相机、上传、网络分析或持久化。

使用 Flutter 3.47.7 / Dart 3.13.5。依赖见 [pubspec](pubspec.yaml)，Pub workspace 管理 diet_models 与 diet_ui。Android 优先，Web/Windows 次之。

```bash
bash tool/flutter.sh pub get
bash tool/flutter.sh run -d <device>
bash tool/verify.sh
```

verify 只做格式、静态检查和 Android/Web/Windows 编译。功能、视觉、真机性能由用户验收；编译不代表运行验收。项目缓存与临时文件隔离在仓库内。

导航：[根规范](AGENTS.md) → [公开概览](doc/README.md)、[架构](doc/architecture.md)、[迁移范围](doc/migration.md)、[库选型](doc/library.md)。

2026-10-20 基础验证结果：

- `dart format --output=none --set-exit-if-changed lib packages test`：通过。
- `bash tool/flutter.sh analyze --no-pub`：通过，无问题。
- `bash tool/flutter.sh build web --no-pub`：通过，产物 `build/web`。
- `bash tool/flutter.sh build windows --debug --no-pub`：通过，产物 `build/windows/x64/runner/Debug/diet_client.exe`。
- Android：尚未编译通过，等待用户自行配置 SDK；已停止自动下载与安装。

Web 构建保留 Flutter 的可选 Cupertino 字体提示；本应用的 Phosphor Regular 字体资源及裁剪已成功。未执行功能、视觉、性能验收或完整测试矩阵。
