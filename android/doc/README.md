# Android 宿主

承载同一套 Flutter 界面，Android 为优先功能目标。绿色组件与玻璃由共享 Flutter UI 包绘制；系统相机/选图、安全存储和时区使用成熟插件，不迁移 RN 原生玻璃或编写自定义桥接。

账号密码、注册和邮件重发使用 Dart Authentik 执行器，无 WebView。真实餐食与营养通过网关接入，资料继续使用 Orion。可选记住登录由系统安全存储提供，主清单禁用自动备份，避免安全密钥与备份密文错配；保留 INTERNET 网络访问。边界见 [登录说明](../../doc/authentication.md)，SDK 由用户自行管理，不因插件接入自行更换。

仓库根目录离线构建入口为 `bash tool/flutter.sh build apk --debug --no-pub --dart-define-from-file=.env.example`；前置环境见 [构建导航](../../tool/AGENTS.md)。

## Release 本地存储与 JNI

锁定的 shared_preferences_android 2.5.1 使用 JNI，外观偏好与记住登录的禁用标记均通过 SharedPreferencesAsync 访问。JNI 签名依赖原始 Kotlin 类型名；release 混淆改名会让偏好读取、保存和登录恢复一起失败。[proguard-rules.pro](../app/proguard-rules.pro) 按 [Flutter 官方修复](https://github.com/flutter/packages/pull/13311) 精确保留六个协程/结果类型，继续启用其余混淆和资源压缩。当前 Flutter Gradle 插件自动加载该规则文件；依赖、存储键及系统安全存储保持原实现。

使用现有 SDK 和签名配置，在项目根目录执行：

```powershell
./tool/flutter.ps1 build apk --release --target-platform android-arm64 --no-pub --dart-define-from-file=.env.example
./tool/check-android-release.ps1
```

检查入口读取本次构建的 R8 mapping，要求六个类型都存在且保持原名。缺失产物或改名均以非零退出；该检查不启动设备、清除数据或调用真实服务。APK 位于 `build/app/outputs/flutter-apk/app-release.apk`，示例配置只用于基础编译，不能用于真实登录。实际执行结果见 [根说明](../../README.md)。

真机验证需用真实公开配置重新构建，由用户核对：外观切换并重启后保留，勾选记住登录后无保存警告、重启可恢复、退出后不恢复旧记录。同一安装的持久化应使用相同 applicationId 和兼容签名；包名变更会隔离应用数据，本轮不迁移旧包存储。构建和 mapping 通过不替代上述验收。

2026-10-20 实际结果：只读预检发现缺少 platforms/android-36/android.jar、build-tools/36.0.0/aapt2.exe，以及 ndk/28.2.13676358 下的 source.properties 和 toolchains/llvm/prebuilt/windows-x86_64/bin/clang.exe。未启动 Android 构建、下载或修改 SDK；verify.sh 在此场景最终返回 2。Android 编译、真机体验与真实登录均未验证，其他结果见 [根说明](../../README.md)。

[宿主导航](../AGENTS.md) · [根规范](../../AGENTS.md)
