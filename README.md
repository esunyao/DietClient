# 膳食健康 DietClient

基于新版绿色 C/B 端样板的 Flutter 客户端。四个入口为首页、配餐、趋势、我的；个人/机构内个人模式在设置中明确选择，宽度只控制布局。

本轮接入「我的」真实姓名/邮箱/头像、基础资料、五类健康档案与 AI 营养同意记录；姓名只读。保留绿色 UI、四导航、玻璃和现有 Authentik/OIDC 登录。记录/草稿、饮食历史、配餐、机构与报告仍为内存演示。不新增注册、令牌刷新、持久化或 AI 分析请求。Web 显式预览保持零会话零业务请求，编辑只作本地演示。

使用 Flutter 3.47.7 / Dart 3.13.5。依赖见 [pubspec](pubspec.yaml)，Pub workspace 包含 diet_oidc、diet_auth、diet_models 与 diet_ui。Android 优先，Web/Windows 次之，SDK 由用户自行管理。

```bash
bash tool/flutter.sh pub get
bash tool/flutter.sh run -d <device> --dart-define-from-file=.env
bash tool/flutter.sh run -d chrome --web-port 7357 --dart-define-from-file=.env
bash tool/verify.sh
```

verify 是完整验证入口；本轮 UI 校准不默认执行全矩阵，仅按改动做格式、静态检查、少量聚焦回归和必要的一次 Web 或 Windows 编译。Android 构建、真机、视觉与性能交给用户，不因验证下载或更换 SDK。构建使用 .env.example 占位配置，不进行真实认证请求；离线测试或编译不代表真实登录、视觉或性能验收。项目缓存与临时文件隔离在仓库内。

登录配置使用被忽略的本地 .env，经 --dart-define-from-file 注入；公开 [.env.example](.env.example) 只保留不可连接占位符与空 client ID。Web 回调为同源静态页面，本地固定 http://localhost:7357/auth-callback.html，通过 AUTHENTIK_WEB_REDIRECT_URI 配置。Web 登录关闭弹窗后可在主页面取消，或等待五分钟超时。配置与平台限制详见 [登录说明](doc/authentication.md)。

真实资料需在本地 `.env` 配置 API_BASE_URL 为部署网关的 HTTPS 基址；`.invalid` 示例会被拒绝，缺失或无效配置显示资料加载错误。客户端不保存凭据或健康资料到磁盘；无会话、Web 显式预览不发送业务请求。Web 部署需允许应用源访问 API，以及对象存储的预签名 PUT/Content-Type 和头像读取，详见 [网络说明](lib/core/network/doc/README.md)。

Windows 使用用户现有 SDK 验证，不下载、更换或升级 SDK。本机关闭 Developer Mode 导致插件 symlink 权限不足时，当前工作区为忽略的 `windows/flutter/ephemeral/.plugin_symlinks` 和 `linux/flutter/ephemeral/.plugin_symlinks` 创建指向本仓库 `.pub-cache` 的目录 junction；Flutter 的 Windows 构建也检查已启用平台的插件链接。这是当前机器缓存处理，不要求全局修改系统设置，不提交这些缓存链接。

## 我的页面功能迁移验证（2026-10-20）

| 检查 | 实际结果 |
|---|---|
| 格式 | `bash tool/dart.sh format --output=none --set-exit-if-changed lib packages/diet_ui/lib test`，98 文件、0 处变更 |
| 静态分析 | `bash tool/flutter.sh analyze --no-pub`，No issues found |
| 资料与相关 UI 回归 | profile_api、profile_widget、authentication_gate、ui_layout、desktop_sidebar_preview、navigation_interaction、glass_backdrop、app_card_material、desktop_sidebar_motion 共 66 项通过 |
| 文档与依赖审查 | 本轮 61 个文件严格 UTF-8 解码通过；318 条相对链接无缺失，根阅读说明保留，原有锁定依赖版本无漂移 |
| Windows debug | `bash tool/flutter.sh build windows --debug --no-pub --dart-define-from-file=.env.example`，成功，13.0s |
| Web release | `bash tool/flutter.sh build web --no-pub --dart-define-from-file=.env.example --dart-define=WEB_UI_PREVIEW=true`，成功，50.0s；Wasm dry run 通过，保留既有 CupertinoIcons 字体资源警告 |

回归包含无损 ID、五类 CRUD 请求、同意版本及排序、无认证头像直传、迟到 401 和换账号隔离、Web 预览无业务客户端、实际库裁剪与取消、配置错误、失败保留输入、短视口大字键盘和原侧栏运动。使用离线替身及示例配置，没有读取真实 `.env`、执行真实登录或业务服务联调，也没有构建 Android/iOS。真实头像存储、后端保存、Android 真机与视觉性能由用户验收。日志位于忽略的 `.local/profile-*.log`。

导航：[根规范](AGENTS.md) → [公开概览](doc/README.md)、[架构](doc/architecture.md)、[迁移范围](doc/migration.md)、[库选型](doc/library.md)、[UI 逻辑尺寸基准](doc/ui-spec.md)。

2026-10-20 异常恢复后的定点修复与验证：

- 已实际复现横屏键盘问题：真实 AppShell + 手工记录页在 844×390、键盘底部遮挡200时，修复前出现底部 RenderFlex 溢出101逻辑像素。
- AppPage 在短视口中将标题、正文与 footer 放入同一个原 ListView，保留顶部导航避让；常规高度仍固定标题与 footer。不关闭文字缩放，键盘开闭保持 Form、字段、Scrollable、输入值和焦点。
- 布局文件新增2项回归，13项通过；其余玻璃、卡片和认证门控13项通过。两组分别执行，共26项通过；静态分析 No issues found，改动的2个Dart文件格式检查零变更。
- 该定点修复阶段未重复平台编译；随后为隔离浏览器白屏，按下条说明单独构建一次 Web release。上述26项为 widget 回归，不是浏览器或 Android 软键盘复现。
- 实际浏览器隔离：用户确认 debug 白屏且 Console 无错误、无警告，仅 DDC 加载日志。HTML/启动脚本返回200，调试服务有 WebSocket 握手失败，但不能据此确定唯一根因。随后使用本地引擎资源构建一次 Web release，退出0，`localhost:7357` 正常创建 flutter-view 并截图显示可用的登录页；源码、依赖、SDK与登录配置均未改。该构建有 CupertinoIcons 字体警告，未扩大依赖处理。
- 点击一次 SSO 后实际提示 `Unable to reach the OIDC endpoint.`，未到账号密码输入阶段、未建立会话、未进入业务首页。已停止重复尝试，等待用户确认身份服务可达；未绕过生产登录。release 产物与截图只在本地忽略目录保存，不提交。

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

2026-10-20 个人首页与玻璃导航补充验证（最终源码）：

| 检查 | 实际结果 |
|---|---|
| 格式 | `bash tool/dart.sh format --output=none --set-exit-if-changed lib packages/diet_ui/lib test`：76文件、0改动，退出0 |
| 静态分析 | `bash tool/flutter.sh analyze --no-pub`：No issues found，6.0s，退出0 |
| 聚焦回归 | `bash tool/flutter.sh test --no-pub test/navigation_interaction_test.dart test/ui_layout_test.dart test/glass_backdrop_test.dart test/app_card_material_test.dart test/authentication_gate_test.dart`：32项通过，退出0 |
| Windows debug | `bash tool/flutter.sh build windows --debug --no-pub --dart-define-from-file=.env.example`：11.5s，退出0；产物 `build/windows/x64/runner/Debug/diet_client.exe` |
| 差异检查 | `git diff --check` 通过 |

本次个人首页使用只读演示目标，今日总量继续来自共享记录；HomeMeals 实现、机构营养、宽屏顶部导航、认证与锁文件未改动。回归包含390/430布局、三态、拖动提交/取消、多指主触点、迷你首手势及键盘、程序化滚动过滤、真实AppShell主体状态、营养未知/超额和大字。减少动画关闭吸附过渡与弹性伸展，保留跟手定位。

本地日志位于 `.local/home-glass-format.log`、`.local/home-glass-test.log`、`.local/home-glass-analyze.log`、`.local/home-glass-windows.log`。这些检查不代表真机折射、视觉还原或性能验收；Android、真实登录及新增Web构建本次未执行，SDK与真实.env未调整。

2026-10-20 桌面侧栏与 Web UI 预览补充：

Windows/Web 在宽度840及以上使用玻璃侧栏，紧凑96、展开216，正文固定左预留120；Android宽屏保持顶栏，窄屏保持原三态底栏。新增预览开关默认关闭且仅Web有效，不建立登录身份或访问认证网关；首页及业务深链接可预览，登录/注册/验证页回首页，页面显示“Web UI 预览 · 未登录”并隐藏退出。隐私遮罩继续可用。

```bash
bash tool/flutter.sh run -d chrome --dart-define-from-file=.env.example --dart-define=WEB_UI_PREVIEW=true
bash tool/flutter.sh build web --no-pub --dart-define-from-file=.env.example --dart-define=WEB_UI_PREVIEW=true
```

本次实际检查：

| 检查 | 结果 |
|---|---|
| 格式 | `bash tool/dart.sh format --output=none --set-exit-if-changed lib packages/diet_ui/lib test`，零变更 |
| 静态分析 | `bash tool/flutter.sh analyze --no-pub`，No issues found |
| 聚焦回归 | `bash tool/flutter.sh test --no-pub test/desktop_sidebar_preview_test.dart test/navigation_interaction_test.dart test/glass_backdrop_test.dart test/authentication_gate_test.dart test/ui_layout_test.dart test/app_card_material_test.dart`，39项通过 |
| Windows debug | `bash tool/flutter.sh build windows --debug --no-pub --dart-define-from-file=.env.example`，成功，23.1s |
| Web release | 上方预览构建命令成功，60.6s；保留既有CupertinoIcons字体资源警告 |

回归包括图表真实绘制与更新、未知值/零值，悬停延迟与反向、鼠标点击后收起、键盘焦点、菜单、触摸切换、短视口大字，以及跨断点/侧栏动画/玻璃切档的页面状态和滚动保留。默认认证门控继续通过；预览以会话为空且认证网关构造即抛错的测试确认隔离。未读取真实.env，未改SDK或依赖。日志保存在忽略目录 `.local/desktop-*.log`；以上不代表浏览器实测、真实登录或视觉与性能验收，Android由用户验证。

## Windows 侧栏连续动画修正（2026-10-20）

本次反馈明确为悬停展开／移出收起的运动不自然，三档玻璃一致，不把它当作已确认的渲染掉帧。修正统一可逆时间线与重复目标处理，每项单图标连续移动、文字固定槽位淡化；账户改传连续进度，保持头像和菜单实例，不再在65%处硬切布局。仍保留96/216宽度、120正文预留、120/180ms悬停延迟、240/200ms完整运动时长；不改玻璃库、捕获策略、依赖、原生宿主或登录边界。

| 检查 | 本次实际结果 |
|---|---|
| 失败复现 | 旧实现重复展开事件后，在原定结束时宽度约116而非216；部分展开反向后仍约105.6而非96。另确认入口双图标和账户名称阈值挂载；对应回归修复后通过 |
| 格式 | `bash tool/dart.sh format --output=none --set-exit-if-changed lib/app/app_shell.dart packages/diet_ui/lib/src/widgets/app_side_navigation.dart test/desktop_sidebar_motion_test.dart`，3文件、0变更 |
| 聚焦回归 | `bash tool/flutter.sh test --no-pub test/desktop_sidebar_motion_test.dart test/desktop_sidebar_preview_test.dart test/glass_backdrop_test.dart test/navigation_interaction_test.dart`，22项通过 |
| 静态分析 | `bash tool/flutter.sh analyze --no-pub`，No issues found，5.2s |
| Windows debug | `bash tool/flutter.sh build windows --debug --no-pub --dart-define-from-file=.env.example`，成功，19.1s；产物 `build/windows/x64/runner/Debug/diet_client.exe` |

新增7项运动回归涵盖中间帧、反向剩余时长、重复事件、单份语义、途中减少动态，以及真实AppShell账户菜单、长名大字和短窗口。日志位于忽略目录 `.local/sidebar-*.log`。AI导航与协作模型已同步，公开入口为 [文档导航](doc/AGENTS.md)，动画实现与验证入口见 [设计系统](packages/diet_ui/AGENTS.md)。

本次未运行真实Windows业务窗口、未执行真实登录，也未追加profile、Web、Android或iOS构建。自动回归和编译不能代替视觉验收；请在现有本地配置启动的Windows客户端中复核三档玻璃的悬停、快速进出、中途反向与账户菜单观感。不新增Windows绕过登录入口，不将本次修复声称为实测帧率提升。
