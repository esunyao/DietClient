# Android 宿主

承载同一套 Flutter 界面，Android 为优先功能目标。绿色组件与玻璃由共享 Flutter UI 包绘制；系统相机/选图、安全存储和时区使用成熟插件，不迁移 RN 原生玻璃或编写自定义桥接。

账号密码、注册和邮件重发使用 Dart Authentik 执行器，无 WebView。真实餐食与营养通过网关接入，资料继续使用 Orion。可选记住登录由系统安全存储提供，主清单禁用自动备份，避免安全密钥与备份密文错配；保留 INTERNET 网络访问。边界见 [登录说明](../../doc/authentication.md)，SDK 由用户自行管理，不因插件接入自行更换。

仓库根目录离线构建入口为 `bash tool/flutter.sh build apk --debug --no-pub --dart-define-from-file=.env.example`；前置环境见 [构建导航](../../tool/AGENTS.md)。

2026-10-20 实际结果：只读预检发现缺少 platforms/android-36/android.jar、build-tools/36.0.0/aapt2.exe，以及 ndk/28.2.13676358 下的 source.properties 和 toolchains/llvm/prebuilt/windows-x86_64/bin/clang.exe。未启动 Android 构建、下载或修改 SDK；verify.sh 在此场景最终返回 2。Android 编译、真机体验与真实登录均未验证，其他结果见 [根说明](../../README.md)。

[宿主导航](../AGENTS.md) · [根规范](../../AGENTS.md)
