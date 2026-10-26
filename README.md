# 膳食健康 DietClient

基于新版绿色 C/B 端样板的 Flutter 客户端。四个入口为首页、配餐、趋势、我的；个人/机构内个人模式在设置中明确选择，宽度只控制布局。

Android/Windows 在「我的」真实资料基础上接入采集草稿、图片上传与识别提交、饮食历史双视图、餐食照片与全屏相册、餐食修正删除、首页及趋势，并扩展注册、邮件重发、会话续期和本机外观设置。姓名只读；营养目标未配置时显示未设置。无公开接口的配餐生成、报告生成、机构菜单同步和独立手工新建显示暂未支持，不模拟真实保存。Web 新功能留到下轮，保留现有登录、资料和独立零请求 UI 预览。

使用 Flutter 3.47.7 / Dart 3.13.5。依赖见 [pubspec](pubspec.yaml)，Pub workspace 包含 diet_oidc、diet_auth、diet_models 与 diet_ui。Android 优先，Windows 同步，本轮不验收 Web 新能力，SDK 由用户自行管理。

```bash
bash tool/flutter.sh pub get
bash tool/flutter.sh run -d <device> --dart-define-from-file=.env
bash tool/flutter.sh run -d chrome --web-port 7357 --dart-define-from-file=.env
bash tool/verify.sh
```

verify 执行格式、静态检查、离线测试及 Web/Windows 示例编译；Android 通过 Flutter 单独构建。本轮历史照片增量已执行格式、静态检查和回归；后续测试、Android/Windows 构建与 ADB 真机验收由用户接手。实际完成和中止项见本页验证记录。仅编译检查可使用 .env.example 占位配置；离线测试或编译不代表真实登录或端到端验收。项目缓存与临时文件隔离在仓库内。

登录配置使用被忽略的本地 .env，经 --dart-define-from-file 注入；公开 [.env.example](.env.example) 只保留不可连接占位符与空 client ID。Web 回调为同源静态页面，本地固定 http://localhost:7357/auth-callback.html，通过 AUTHENTIK_WEB_REDIRECT_URI 配置。Web 登录关闭弹窗后可在主页面取消，或等待五分钟超时。配置与平台限制详见 [登录说明](doc/authentication.md)。

真实功能需在本地 `.env` 配置 API_BASE_URL 为部署网关的 HTTPS 基址；`.invalid` 示例会被拒绝。注册使用 example 中的 enrollment 和 resend flow 配置。登录默认不记住，仅在内存续期；勾选后才把刷新令牌和必要身份上下文写入系统安全存储，不保存密码、健康资料、图片或签名 URL。部署方需启用 offline_access 及对应 scope mapping，否则只能使用本次有效会话。无会话或 Web 显式预览不发送业务请求，见 [网络说明](lib/core/network/doc/README.md) 与 [登录说明](doc/authentication.md)。

Windows 使用用户现有 SDK 验证，不下载、更换或升级 SDK。本机关闭 Developer Mode 导致插件 symlink 权限不足时，当前工作区为忽略的 `windows/flutter/ephemeral/.plugin_symlinks` 和 `linux/flutter/ephemeral/.plugin_symlinks` 创建指向本仓库 `.pub-cache` 的目录 junction；Flutter 的 Windows 构建也检查已启用平台的插件链接。这是当前机器缓存处理，不要求全局修改系统设置，不提交这些缓存链接。

## Android release 构建与自定义签名

以下命令在项目根目录使用 Git Bash 执行。先自行准备项目所需的 Android SDK、Build Tools、NDK 与 JDK，再使用既有工具入口构建；不自动下载或更换 SDK。下面是构建方法，不代表本仓库已完成 Android release 或真机验证。

### 1. 指定自己的签名密钥

已有 `.jks` 或 `.keystore` 时直接使用，不要为升级已发布应用重新生成密钥。建议将密钥文件保存在仓库外，在本地创建 `android/key.properties`，按实际情况填写：

```properties
storeFile=E:/Keys/diet-release.jks
storePassword=替换为密钥库密码
keyAlias=替换为密钥别名
keyPassword=替换为该别名的密钥密码
```

`storeFile` 使用 Windows 绝对路径和正斜杠 `/`；值不额外加引号。上面的路径与密码均为示例，不是真实配置。忘记别名时可运行以下命令，在交互提示中输入密码，不把密码放到命令行参数中：

```bash
keytool -list -v -keystore "E:/Keys/diet-release.jks"
```

签名读取入口为 [android/app/build.gradle.kts](android/app/build.gradle.kts)。使用 `Properties()` 读取配置时，须在文件顶部、`plugins` 块之前导入：

```kotlin
import java.util.Properties
```

Gradle 应从 `rootProject.file("key.properties")` 加载上述配置，将四个属性绑定到 `signingConfigs.create("release")` 的 `storeFile`、`storePassword`、`keyAlias`、`keyPassword`，并在 `buildTypes.release` 中指定：

```kotlin
signingConfig = signingConfigs.getByName("release")
```

不要使用 `signingConfigs.getByName("debug")` 签署正式发布包，也不要在缺失配置时回退到 debug 签名。[android/.gitignore](android/.gitignore) 已忽略 `key.properties`、`*.jks` 与 `*.keystore`；不要强制添加这些文件，不在源码、日志或聊天中公开密钥和密码。

### 2. 构建 APK 或 AAB

本地 `.env` 填写真实 API 与登录公开参数；仅验证编译时可将命令中的 `.env` 换为 `.env.example`，但占位配置不能用于真实登录或业务请求。签名密码只放在 `key.properties`，不要放入 `.env` 或 `--dart-define`；编译期注入不是秘密存储，配置可能进入客户端产物。

```bash
# 首次构建或依赖变更后解析依赖
bash tool/flutter.sh pub get

# 通用 release APK，用于直接安装
bash tool/flutter.sh build apk --release --dart-define-from-file=.env

# 可选：按 CPU 架构拆分 APK，减小单个安装包体积
bash tool/flutter.sh build apk --release --split-per-abi --dart-define-from-file=.env

# AAB，用于 Google Play 等支持 App Bundle 的渠道
bash tool/flutter.sh build appbundle --release --dart-define-from-file=.env
```

按需要选择一种构建方式，无需全部执行。

| 构建方式 | 产物位置 |
|---|---|
| 通用 APK | `build/app/outputs/flutter-apk/app-release.apk` |
| 分架构 APK | `build/app/outputs/flutter-apk/app-<abi>-release.apk`，例如 `app-arm64-v8a-release.apk` |
| AAB | `build/app/outputs/bundle/release/app-release.aab` |

### 3. 发布前核对

- 使用 Android SDK Build Tools 的 `apksigner` 校验 APK：`apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk`；工具不在 PATH 时使用其完整路径，并将签名证书 SHA-256 指纹与自己的证书核对。
- 升级已安装应用须保持相同 `applicationId` 和兼容的应用签名证书，并递增版本号；项目版本来自 `pubspec.yaml`，也可通过 Flutter 的 `--build-name`、`--build-number` 指定。
- 启用 Google Play App Signing 时，构建上传包使用已登记的上传密钥，最终分发应用由 Play 使用应用签名密钥签署，不混淆两类密钥。
- `applicationId` 以 [应用构建配置](android/app/build.gradle.kts) 为准；首次正式发布前确认包名，变更后 Android 会使用独立的应用存储，旧包的登录与外观不会自动迁移。
- 签名成功不代表登录、头像直传或 UI 已验收，仍需使用 release 包完成 Android 真机验证。

## Android release 持久化修复验证（2026-10-21）

本次针对 release 下启动恢复、记住登录与外观设置同时失败，增加 [六项 JNI 类型保留规则](android/app/proguard-rules.pro) 并检查实际 R8 mapping。沿用现有依赖、安全存储与 SharedPreferencesAsync；规则由当前 Flutter Gradle 插件自动加载，保持其余混淆和资源压缩。

| 检查 | 本次实际结果 |
|---|---|
| 原产物问题复现 | 原有真实 R8 mapping 的六项均未满足原名保留要求；检查脚本退出 1，原 mapping 文件哈希保持不变 |
| 当时的检查脚本（现已删除） | Windows PowerShell 5.1 下 15 项通过，涵盖原名、改名、缺类、嵌套 `$Failure`、重复/伪条目、不可读文件、空格路径及跨目录调用 |
| 会话与外观回归 | `full_foundation`、`auth_auxiliary_functional`、`preferences_functional`、`session_restore_ui` 共 42 项通过 |
| 格式与分析 | 139 个 Dart 文件、0 处格式变更；`flutter analyze --no-pub` 无问题，101.5s |
| 文档 | 本轮文件严格 UTF-8 解码和相对链接检查通过，私有规划保持忽略 |
| Android release | 构建由用户接手；AI 未执行本次 release 编译，也未下载或调整 SDK |
| 修复后产物检查 | 用户提供实际 R8 mapping 检查输出，六个类型全部 PASS |
| 真机结果 | 2026-10-21 用户确认 Android release 登录与外观持久化问题已解决；验收由用户完成 |

构建与检查命令、用户验收步骤见 [Android 宿主说明](android/doc/README.md)。本轮没有读取真实 `.env` 或签名文件内容，没有安装、卸载或清除设备数据。用户当前的包名、依赖与源码未提交修改单独保留，不夹带提交。日志位于本地忽略的 `.local/android-release-persistence-*.log`。

## Android / Windows 全页面功能迁移验证（2026-10-21）

在中断前的会话、网络、采集、餐食、首页与趋势实现上，已集成注册、邮件重发、记住登录入口及本机外观持久化；沿用已完成的「我的」。另修复慢 GET 被轮询反复作废、切换筛选继承旧超时，以及注册取消后的迟到回调影响新输入的问题。旧演示几何回归显式绑定演示分支，保留原有断言。

| 检查 | 本次实际结果 |
|---|---|
| 格式 | `bash tool/dart.sh format --output=none --set-exit-if-changed lib packages test`，139 文件、0 处变更 |
| 静态分析 | `bash tool/flutter.sh analyze --no-pub`，No issues found，14.5s |
| 应用回归 | `bash tool/flutter.sh test --no-pub`，133 项通过，含既有资料、导航、裁剪及本轮真实功能 |
| 协议与执行器 | `bash tool/dart.sh test packages/diet_oidc/test packages/diet_auth/test`，34 项通过 |
| Windows debug | `bash tool/flutter.sh build windows --debug --no-pub --dart-define-from-file=.env.example`，成功，63.6s；产物 `build/windows/x64/runner/Debug/diet_client.exe` |
| 依赖边界 | 对比本轮开始前的锁定文件，既有依赖版本无变化；仅增加批准依赖及其传递依赖 |
| 导航与编码 | 本次续做 40 个变更文件严格 UTF-8 解码通过，150 条公开相对链接无缺失；根阅读说明保持原文，私有规划未跟踪 |

第一轮应用检查为119项通过、4项旧演示fixture失败；明确演示/真实装配分支后最终133项全部通过。第一轮静态问题亦已修复。测试使用离线替换边界，不读取真实 `.env`、不调用部署端点；构建成功不证明实际 Authentik、邮件、对象存储或系统安全存储联通。Android 构建、真机、视觉及性能由用户验收；本轮没有追加 Web 或 iOS 构建。

真实运行继续使用本地 `.env` 的 API 和 Authentik 公开配置；注册另需 enrollment 与 resend flow。登录默认不勾选“记住登录”，只有勾选才保存刷新凭据；不能获取刷新令牌时保留当前有效会话并提示。外观自动保存在本机；“恢复默认外观”不清除健康资料、餐食、同意或会话。无公开接口的配餐、报告、机构同步和独立手工新建保持暂未支持。Web 继续原功能与独立显式 UI 预览。

日志位于忽略的 `.local/resume-all-test.log`、`.local/resume-auth-test.log`、`.local/resume-analyze.log`、`.local/resume-windows-debug.log`。模块及测试入口见 [迁移对照](doc/migration.md)、[认证说明](doc/authentication.md)、[测试导航](test/AGENTS.md)。

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

Android 缺少 API 36 的 android.jar、Build Tools 36.0.0 的 aapt2.exe，以及 NDK 28.2.13676358 的 source.properties 和 clang.exe。SDK 由用户自行配置；当时的 Android 预检步骤报告部分完成，不能把已完成的 Web/Windows 编译当作全部平台通过。该步骤现已移除，Android 改为单独构建。

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

## 2026-10-25 前端审查修正

统一资料、健康与餐食表单的返回／路由离开保护，保存中阻止离开及打开设置；无返回栈时转往明确业务页面。异步操作完成只在原页面仍可见时导航，避免覆盖后来打开的页面。首页及趋势使用共享本地日期，在午夜及恢复前台时更新。

真实显示模式和隐私遮罩移出 demo，真实／演示入口先分流再创建控制器；演示标识由演示页面显式传入。网络层提供本地安全的分类错误提示，资料页面保留具体提示与未保存输入，不直接显示服务端原始消息。Bash 脚本固定 LF。未升级依赖、修改 SDK 或读取真实 .env，原有 diet_app.dart 注释保留。

最终验证（使用 tool/ 既有入口）：

| 检查 | 结果 |
|---|---|
| Dart 格式检查 | 148 文件、0 改动，退出 0 |
| flutter analyze --no-pub | No issues found，退出 0 |
| flutter test --no-pub --reporter expanded | 193 项通过，包含新增 60 项回归，退出 0 |
| Windows debug | --no-pub --dart-define-from-file=.env.example，编译成功，退出 0 |
| Bash 与文档 | 三份脚本 LF、bash -n 通过；受影响公开文档及导航同步 |

新回归覆盖侧栏取消／放弃、保存中离开、认证失效优先、无栈成功返回、迟到结果不挤走页面、本地午夜与隔夜恢复、分类错误、显示状态隔离、入口隔离及真实页面的窄屏／大字／键盘与失败重试。运行记录位于忽略目录 .local/frontend-*.log。

Android、真实服务、真机视觉和性能未验证；Windows 编译不代表这些验收完成。

## 2026-10-26 账户名称回退

统一账户名称优先使用去除首尾空白后的 displayName；缺失、null、空字符串或纯空白时显示 username，两者均为空时显示“姓名未提供”。我的页面和侧栏共用该规则，不修改数据库和后端。

验证：新增 10 项账户名称回归，与 profile API、profile widget、侧栏运动回归合计 37 项通过；两份 Dart 文件格式检查通过；`tool/flutter.ps1 analyze --no-pub` 无问题；Windows debug 使用 `.env.example` 编译成功。未进行真实客户端视觉验收。


## 历史餐食照片与双视图（2026-10-26）

Android/Windows 已增加紧凑列表与照片卡片，默认紧凑列表，在应用设置的“饮食历史显示方式”中切换并保存在本机。点击餐食文字进入详情，点击真实照片进入独立全屏相册；详情支持多图，相册支持翻页、缩放、双击复位以及键盘和系统返回。查询组合现有餐食详情与采集会话接口，仅显示 confirmed 图片。

对象图片通过独立无认证 Dio 读取；签名过期或 401/403 时合并刷新一次，其他失败显式重试。图片和签名仅驻留当前账户的活动内存，离页或换号释放，不使用示例食物补图。复用既有依赖与 Flutter 控件，未新增依赖或升级锁定版本；Web 保持原有业务隔离。

| 检查 | 用户接手前的实际结果 |
|---|---|
| 照片专项回归 | 最终 58 项通过，包含慢签名刷新、重试上限、换号清理和快速滑动 |
| 完整 Flutter 测试 | 283 项通过；随后只清理两处测试风格提示，未改变测试行为 |
| Dart 格式 | tool/dart.sh format --output=none --set-exit-if-changed lib packages test，161 文件、0 处变更 |
| 静态分析 | tool/flutter.sh analyze --no-pub，No issues found；首次两处测试风格提示已清理 |
| Android debug | 已启动使用本地 .env 的构建，用户接手测试后主动中止；没有可报告的成功构建结果 |
| Windows debug | 本轮未执行，由用户接手 |
| 当前构建的 ADB 真机验收 | 未执行；未安装、卸载或清除设备数据，由用户接手 |

先前专项检查暴露的页面高度约束、键盘焦点与重试点击问题已修复。追加集成用例实际复现了慢签名刷新导致重试预算重置、快速首帧滑动被缩放手势截获的问题，修复后上述专项及完整测试通过。离线测试不代表真实后端照片或签名可达；真实照片、两布局切换、相册返回和应用重启恢复仍由用户验收。

测试入口见 [照片回归导航](test/AGENTS.md)、[构建工具](tool/AGENTS.md)；运行日志仅保存在忽略的 .local/meal-photo-*.log。全部变更在 dev/feature 当前分支完成，没有创建工作树、切换分支或推送。
