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

2026-10-20 异常恢复后的定点修复与验证：

- 已实际复现横屏键盘问题：真实 AppShell + 手工记录页在 844×390、键盘底部遮挡200时，修复前出现底部 RenderFlex 溢出101逻辑像素。
- AppPage 在短视口中将标题、正文与 footer 放入同一个原 ListView，保留顶部导航避让；常规高度仍固定标题与 footer。不关闭文字缩放，键盘开闭保持 Form、字段、Scrollable、输入值和焦点。
- 布局文件新增2项回归，13项通过；其余玻璃、卡片和认证门控13项通过。两组分别执行，共26项通过；静态分析 No issues found，改动的2个Dart文件格式检查零变更。
- 本次未重复 Web/Windows 编译或 Android 构建。上述为 widget 回归，不是浏览器或 Android 软键盘复现。
- 实际浏览器预览另有阻塞：CDP 已连接并截图；`127.0.0.1:7357` 显示登录页，但提示 Web 回调同源配置不匹配；`localhost:7357` 白屏，尚未出现 flutter-view。两地址 HTML/启动脚本均返回200且字节一致，调试服务日志有 WebSocket 握手失败，但根因尚未确认。已停止重复连接，等待浏览器 Console 的第一条错误；未修改登录配置、绕过门控或验证真实登录。

2026-10-20 全量 UI 校准阶段验证（与下方前序登录记录分开）：

| 项目 | 实际结果 |
|---|---|
| Dart 格式 | `bash tool/dart.sh format --output=none --set-exit-if-changed lib packages test`，84 个文件、0 处变更，退出 0 |
| 静态检查 | `bash tool/flutter.sh analyze --no-pub`，No issues found，退出 0 |
| 聚焦回归 | UI 布局、卡片 Material、Windows 玻璃和登录门控 4 个文件，共 24 项通过，退出 0 |
| Windows debug | 使用 `.env.example` 编译成功，退出 0；产物 `build/windows/x64/runner/Debug/diet_client.exe` |
| 导航与编码 | 548 条公开相对链接无缺失；源文件严格 UTF-8 解码无错误，根阅读说明保持原文 |
| Android | 本轮未构建或运行，交由用户验收，不安装或改动 SDK |
| Web / 真机视觉与性能 | 未追加 Web 编译、浏览器矩阵或真机性能验证；尚未完成视觉验收 |

首轮检查发现并已修复多余导入、标题中心偏移、营养卡偏高、平板餐食行溢出和测试语义句柄清理问题；上述结果为修复后的复跑结果。其后另修正宽屏标题与辅助信息等分挤压，11 项布局回归再次通过；该最后的纯布局定点修复未重复整个平台编译。Windows 编译未执行真实登录，不证明身份服务当前联通。

本轮保持已锁定依赖、认证协议、内存会话、业务演示统计与平台宿主不变，改动集中在 presentation、设计系统、导航与说明。手机个人首页和平板机构首页已按目标逻辑尺寸校准，其余既有页面同步调整；功能和视觉仍需用户实际核验。标题改为固定后，宽屏业务内容在标题下方独立滚动，不再滑到顶部导航后方；Windows 背景捕获后端保留，但不能把当前顶栏的纯色背景称为可见的滚动折射效果。

Android 建议优先验证：个人首页卡片与底栏比例；切换机构模式后双栏顺序；二级返回及固定保存按钮；修正后摘要联动；玻璃三档与减少透明度；窄屏大字和键盘是否遮挡。使用现有本地配置启动：

```bash
bash tool/flutter.sh run -d <android-device-id> --dart-define-from-file=.env
```

当前运行截图尚待用户补充；收到后以新反馈记录定位具体偏差，不把参考图当作实机结果。

2026-10-20 前序登录阶段实际验证结果：

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
