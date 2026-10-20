# 库与封装

依赖解析以 [pubspec.lock](../pubspec.lock) 为准，下表沿用已锁定的选择；本轮 UI 校准不新增或升级依赖。项目记录的本机基线为 Flutter 3.47.7 / Dart 3.13.5，SDK 由用户管理，不自动下载、替换或升级。几何与字阶目标见 [UI 规格](ui-spec.md)。

| 能力 | 选择 | 封装 |
|---|---|---|
| 路由 | [go_router](https://pub.dev/packages/go_router) 18.1.0 | app/router |
| UI状态 | [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) 3.4.3 | core 与 demo |
| 图表 | [fl_chart](https://pub.dev/packages/fl_chart) 1.2.0 | diet_ui |
| 图标 | [phosphor_flutter](https://pub.dev/packages/phosphor_flutter) 2.1.0 | diet_ui 图标入口 |
| SVG | [flutter_svg](https://pub.dev/packages/flutter_svg) 2.3.0 | 本地原稿插画 |
| 玻璃 | [liquid_glass_easy](https://pub.dev/packages/liquid_glass_easy) 5.0.0 | diet_ui；关闭/标准/增强与能力回退 |
| 通用 OIDC | 本地纯 Dart diet_oidc；openid_client 0.4.10+2、http 1.6.0、web 1.1.1、jose 0.3.5+1 | PKCE/令牌模型复用、受约束授权码交换、JWKS 验签及 Web 弹窗条件导出 |
| Authentik 流程 | 本地纯 Dart diet_auth；dio 5.11.1、dio_cookie_manager 3.5.0、cookie_jar 4.0.9 | 内存 Cookie 与有限阶段执行器；依赖 diet_oidc |
| Dart 包测试 | test 1.31.1 | 包内离线协议与执行器验证，不代表真实身份提供方联通 |

玻璃参考 FlClash 的设置交互，使用 Flutter 绘制，避免原生桥接。标准为轻量磨砂；增强在支持的渲染器实时折射，Windows Skia 通过 GlassBackdrop 捕获真实背景（同步、pixelRatio 1、high 约60fps），Web 回退磨砂；高对比/减少透明度优先实体。仅导航、浮层与必要操作区域使用玻璃。

GlassBackdrop 的背景只装配一次，overlay 不参与捕获。Windows 容器跨档位稳定，仅增强且 shader 成功后持续捕获；标准、关闭、无障碍与 shader 失败不持续捕获，库首次挂载可有一次初始化捕获。GlassSurface 根据实际后端加载 shader，失败回退磨砂。

视觉遵循新版绿色样板；系统中文字体回退，本地矢量插画，Phosphor regular 图标。表单、日期、弹层优先 Flutter 标准组件。共享包提供稳定展示接口，第三方 API 不散布到各 feature。布局使用 LayoutBuilder 等实际约束与逻辑尺寸 tokens，不引入 ScreenUtil 式全局缩放，也不关闭系统文字缩放。

Flutter 3.47 将 IconData 设为 final，phosphor_flutter 2.1.0 的继承式图标类无法编译。diet_ui 的 AppIcons 使用核对过的 Regular 字体码点和标准 const IconData，仍由该包提供字体；不直接导入旧 Dart 图标类，不修改缓存。此边界保持 release Web 的字体裁剪可用。

登录依赖已由包声明和根 pubspec.lock 核对。diet_oidc 只复用 openid_client 的 PKCE Flow 与令牌模型，使用受约束 http 执行授权码交换和 JWKS 获取，避免库内通用交换路径记录原始 Token 响应；jose 负责签名验证，客户端补充 claims/nonce 检查。既有登录保留真实联网，其余业务仍为内存演示；本轮 UI 校准不增加网络能力，详见 [登录边界](authentication.md)。
