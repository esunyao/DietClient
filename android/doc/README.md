# Android 宿主

承载同一套 Flutter 演示界面，Android 为本轮优先编译目标。绿色组件与玻璃由共享 Flutter UI 包绘制，没有迁移 RN 原生玻璃、真实采集或权限流程。

本轮新增账号密码登录实现，使用 Dart 直连和内存会话，无原生桥接或 WebView；其余业务保持演示。主清单已声明 INTERNET 网络访问，登录边界和验证状态见 [登录说明](../../doc/authentication.md)。SDK 由用户自行管理。

仓库根目录离线构建入口为 `bash tool/flutter.sh build apk --debug --no-pub --dart-define-from-file=.env.example`；前置环境见 [构建导航](../../tool/AGENTS.md)。

2026-10-20 实际结果：只读预检发现缺少 platforms/android-36/android.jar、build-tools/36.0.0/aapt2.exe，以及 ndk/28.2.13676358 下的 source.properties 和 toolchains/llvm/prebuilt/windows-x86_64/bin/clang.exe。未启动 Android 构建、下载或修改 SDK；verify.sh 在此场景最终返回 2。Android 编译、真机体验与真实登录均未验证，其他结果见 [根说明](../../README.md)。

[宿主导航](../AGENTS.md) · [根规范](../../AGENTS.md)
