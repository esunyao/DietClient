# 膳食健康 DietClient

基于新版绿色 C/B 端样板的 Flutter 客户端。四个入口为首页、配餐、趋势、我的；个人/机构内个人模式在设置中明确选择，宽度只控制布局。

本轮只校准 UI：保留现有 Authentik/OIDC 登录与启动门控，不扩展真实登录或业务集成。记录/草稿、历史、详情与份量修正、配餐、机构、报告、健康档案及 AI 授权继续演示；业务共享状态只保留内存，重启或重置恢复样例。不接入注册、邮箱验证、MFA、业务 API、相机、上传、网络分析、Token 刷新或持久化。

使用 Flutter 3.47.7 / Dart 3.13.5。依赖见 [pubspec](pubspec.yaml)，Pub workspace 包含 diet_oidc、diet_auth、diet_models 与 diet_ui。Android 优先，Web/Windows 次之，SDK 由用户自行管理。

```bash
bash tool/flutter.sh pub get
bash tool/flutter.sh run -d <device> --dart-define-from-file=.env
bash tool/flutter.sh run -d chrome --web-port 7357 --dart-define-from-file=.env
bash tool/verify.sh
```

verify 是完整验证入口；本轮 UI 校准不默认执行全矩阵，仅按改动做格式、静态检查、少量聚焦回归和必要的一次 Web 或 Windows 编译。Android 构建、真机、视觉与性能交给用户，不因验证下载或更换 SDK。构建使用 .env.example 占位配置，不进行真实认证请求；离线测试或编译不代表真实登录、视觉或性能验收。项目缓存与临时文件隔离在仓库内。

登录配置使用被忽略的本地 .env，经 --dart-define-from-file 注入；公开 [.env.example](.env.example) 只保留不可连接占位符与空 client ID。Web 回调为同源静态页面，本地固定 http://localhost:7357/auth-callback.html，通过 AUTHENTIK_WEB_REDIRECT_URI 配置。Web 登录关闭弹窗后可在主页面取消，或等待五分钟超时。配置与平台限制详见 [登录说明](doc/authentication.md)。

导航：[根规范](AGENTS.md) → [公开概览](doc/README.md)、[架构](doc/architecture.md)、[迁移范围](doc/migration.md)、[库选型](doc/library.md)、[UI 逻辑尺寸基准](doc/ui-spec.md)。

2026-10-20 登录阶段实际验证结果：

| 项目 | 结果 |
|---|---|
| 依赖解析 | pub get 退出 0 |
| 格式与脚本 | 65 个 Dart 文件格式检查通过；4 个 Bash 脚本 bash -n 通过，退出均为 0 |
| 静态检查 | flutter analyze：No issues found，退出 0 |
| 协议与执行器 | 24 项离线测试通过，退出 0 |
| 应用登录门控 | 门控、过期、配置、取消等 6 项离线测试通过，退出 0 |
| Web release | .env.example 构建通过，退出 0；产物 build/web，含 auth-callback.html 与 auth-callback.js |
| Windows debug | .env.example 构建通过，退出 0；产物 build/windows/x64/runner/Debug/diet_client.exe |
| Android | 关键文件预检未通过，未启动构建、下载或修改 SDK |

Android 缺少 API 36 的 android.jar、Build Tools 36.0.0 的 aapt2.exe，以及 NDK 28.2.13676358 的 source.properties 和 clang.exe。SDK 由用户自行配置；缺失时 verify.sh 保留退出码 2，不能把已完成的 Web/Windows 编译当作全部平台通过。

真实登录仍未验证，client ID 为空。先前公开探测曾返回 502，该历史结果不表示当前部署仍返回 502。以上离线测试和构建没有完成真实认证，也不替代用户的功能、视觉、真机性能验收。
