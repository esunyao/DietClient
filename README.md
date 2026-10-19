# 膳食健康 DietClient

基于新版绿色 C/B 端样板的 Flutter 客户端。四个入口为首页、配餐、趋势、我的；个人/机构内个人模式在设置中明确选择，宽度只控制布局。

本轮仅登录接入真实 Authentik/OIDC，启动先登录。记录/草稿、历史、详情与份量修正、配餐、机构、报告、健康档案及 AI 授权继续演示；业务共享状态只保留内存，重启或重置恢复样例。不接入注册、邮箱验证、MFA、业务 API、相机、上传、网络分析、Token 刷新或持久化。

使用 Flutter 3.47.7 / Dart 3.13.5。依赖见 [pubspec](pubspec.yaml)，Pub workspace 按规划增加 diet_oidc 与 diet_auth，保留 diet_models 与 diet_ui。Android 优先，Web/Windows 次之，SDK 由用户自行管理。

```bash
bash tool/flutter.sh pub get
bash tool/flutter.sh run -d <device> --dart-define-from-file=.env
bash tool/flutter.sh run -d chrome --web-port 7357 --dart-define-from-file=.env
bash tool/verify.sh
```

verify 只做格式、静态检查和 Android/Web/Windows 编译。功能、视觉、真机性能由用户验收；编译不代表运行验收。项目缓存与临时文件隔离在仓库内。

登录配置使用本地 .env，经 --dart-define-from-file 注入；公开 .env.example 只保留不可连接占位符与空 client ID。Web 回调为同源静态页面，本地固定 http://localhost:7357/auth-callback.html，通过 AUTHENTIK_WEB_REDIRECT_URI 配置。集成中需要落实本地环境文件忽略规则，详见 [登录说明](doc/authentication.md)。

导航：[根规范](AGENTS.md) → [公开概览](doc/README.md)、[架构](doc/architecture.md)、[迁移范围](doc/migration.md)、[库选型](doc/library.md)。

2026-10-20 原 UI 阶段基础验证结果（不代表新增登录代码已验证）：

- `dart format --output=none --set-exit-if-changed lib packages test`：通过。
- `bash tool/flutter.sh analyze --no-pub`：通过，无问题。
- `bash tool/flutter.sh build web --no-pub`：通过，产物 `build/web`。
- `bash tool/flutter.sh build windows --debug --no-pub`：通过，产物 `build/windows/x64/runner/Debug/diet_client.exe`。
- Android：尚未编译通过，等待用户自行配置 SDK；已停止自动下载与安装。

Web 构建保留 Flutter 的可选 Cupertino 字体提示；本应用的 Phosphor Regular 字体资源及裁剪已成功。未执行功能、视觉、性能验收或完整测试矩阵。

新增登录接入中；当前已知公开探测返回 502，尚未验证真实登录。该阶段的静态检查、编译与实际登录结果待实施收尾分别补充。
