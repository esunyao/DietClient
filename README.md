# DietClient

饮食健康管理客户端，基于 React Native 0.86、React 19 和 TypeScript，同时支持 Android、iOS 与 Web 调试壳。

## Requirements

- Node.js `>=22.11.0`
- npm（使用 `npm ci` 安装锁定依赖）
- Android Studio / Android SDK（Android）
- macOS、Xcode 与 CocoaPods（iOS）

本机配置从 `src/shared/config/appConfig.ts.template` 复制；真实 `appConfig.ts` 已忽略，不能提交。

## Structure

```text
src/
├── app/session/                 # token、用户、档案与会话生命周期
├── features/
│   ├── auth/                    # Authentik/OIDC、登录注册页面
│   ├── diet/                    # 餐食识别、历史、详情、修正与统计页面
│   └── profile/                 # 档案、头像和五类健康记录
├── navigation/                  # 路由组合、参数类型、页面元数据
└── shared/                      # HTTP、layout/primitives、主题、上传、动画和原生表面
```

完整依赖规则、数据流和“应该修改哪里”索引见 [架构说明](docs/architecture.md)。

## Development

```sh
npm ci
npm start                 # Metro
npm run android           # Android
npm run ios               # iOS（macOS）
npm run start:web         # http://localhost:8080
```

iOS 首次安装或原生依赖变化后运行：

```sh
bundle install
bundle exec pod install
```

## Verification

```sh
npm run format:check
npm run lint
npm run typecheck
npm test -- --runInBand
npm run build:web
npm run verify             # 顺序执行以上全部检查
npm run test:android       # 需要有效的本机 Android SDK
```

## Web notes

- `web/index.html` 的 `#root` 必须保持 flex 有界高度，否则 React Native Web 的滚动容器无法正确计算。
- 页面外壳通过 CSS 变量 `--phone-w` / `--phone-h` 控制；全局 Web CSS 不与 React Native `StyleSheet` 混用。
- `web/webpack.config.js` 的 Windows 路径排除规则需同时兼容 `/` 和 `\\`。
- 头像 Web 上传使用对象存储预签名 PUT；存储桶必须允许本机开发 origin 的 CORS 预检。

## Troubleshooting

- Android JVM 测试找不到 SDK：修正本机 `android/local.properties` 的 `sdk.dir`，不要提交该文件。
- Web 上传被拦截：检查对象存储 CORS，而不是把预签名地址改成应用 API 地址。
- iOS 原生依赖错误：在 macOS 重新执行 `bundle exec pod install`。
- 结构审查中已知但未改变行为的问题见 [代码审查记录](docs/code-review-findings.md)。
