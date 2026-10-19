# Web 宿主

业务页面展示相同的 Flutter 内存演示。真实登录通过弹窗、同源静态回调和 BroadcastChannel 接入，参数与 Token 不落地；浏览器不接入业务相机、上传或持久化。玻璃由纯 Flutter 共享组件绘制，能力不足时回退。

本地启动固定 `--web-port 7357 --dart-define-from-file=.env`，AUTHENTIK_WEB_REDIRECT_URI 为 http://localhost:7357/auth-callback.html；部署回调与应用同源。实际接入和验证状态见 [登录说明](../../doc/authentication.md)。

仓库根目录离线构建入口为 `bash tool/flutter.sh build web --no-pub --dart-define-from-file=.env.example`。环境与实际结果见 [根说明](../../README.md)、[构建导航](../../tool/AGENTS.md)。Web 编译通过不代表 Android、Windows 或真实弹窗登录已验收。

2026-10-20 实际结果：Web release 使用 .env.example 编译退出 0，产物为 build/web，auth-callback.html 与 auth-callback.js 均存在于产物中。client ID 为空，未完成真实弹窗登录或用户功能、视觉和性能验收。

[宿主导航](../AGENTS.md) · [根规范](../../AGENTS.md)
