# DietClient Repository Guide

## Shell, encoding, and line endings

- 默认使用 Git Bash 执行命令。
- PowerShell 必须先设置 UTF-8：`chcp 65001; [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); $OutputEncoding = [System.Text.UTF8Encoding]::new($false)`。
- 不得仅凭终端乱码判断文件损坏。改写含非 ASCII 文本前先严格按 UTF-8 解码验证，并尽量保留原编码。
- 源码使用 UTF-8 无 BOM 和 LF；`.bat/.cmd` 使用 CRLF。Windows PowerShell 5.1 的非 ASCII `.ps1` 可使用 UTF-8 BOM 与 CRLF。
- 遵守 `.editorconfig`、`.gitattributes`、Prettier 和 ESLint，不提交编辑器意外造成的全库行尾变更。

## Architecture and dependency boundaries

DietClient 是 React Native 0.86、React 19、TypeScript 和 npm 项目。根组件为 `App.tsx`，原生和 Web 入口分别为 `index.js` 与 `index.web.js`。

```text
App / navigation
       ↓
app/session（会话编排，可组合 auth 与 profile）
       ↓
features/{auth,diet,profile}
       ↓
shared
```

- `src/app/` 只放跨 feature 的应用级编排；会话恢复、token 生命周期和登录态位于 `src/app/session/`。
- `src/features/<domain>/` 拥有本领域的 API 类型、页面、组件和服务。feature 之间不得直接导入；页面可以消费 app session。
- `src/shared/` 不得导入 `app`、`navigation` 或任何 feature，只放无业务归属的基础能力。
- `src/navigation/` 只组合路由和维护参数类型，不承载业务流程。
- 不新增路径别名；保持 Metro、Webpack、Jest 和 TypeScript 使用一致的相对路径解析。

## Files and abstractions

- 一个 React Navigation 路由页面对应一个同名 `*Screen.tsx` 文件，便于按路由名定位。
- 页面私有小组件、私有函数和 `StyleSheet.create` 默认与页面共置；不要批量创建 `.styles.ts`。
- 仅当代码复用至少两处、包含独立状态流程、存在平台变体或可独立测试时才抽离。
- service 有多个实现、测试或平台变体时使用独立目录和公共 `index.ts`；单文件内部实现不机械创建 barrel。
- 保留 `.native/.web/.android/.ios` 平台后缀和 Native Codegen 文件名。不得更改 Native Module 名、Fabric component 名、JS prop、资源 ID 或 component provider。
- 公共组件统一从 `src/shared/components` barrel 导入；barrel 只导出稳定公共 API，不导出私有实现。

## TypeScript, naming, and comments

- 遵循 ESLint/Prettier：两空格、单引号、尾逗号；组件和页面用 PascalCase，变量和函数用 camelCase。
- 采用 Google TypeScript Style Guide 中适用于外部 React Native 项目的规则：限制导出面、优先简单显式类型、纯类型依赖使用 `import type`、避免不安全动态索引和复杂条件类型。
- `App.tsx`、React Native 注册入口及 Codegen 声明可按框架要求使用默认导出；业务模块使用命名导出。
- 注释使用中文，解释模块边界、原因、协议约束、状态机、并发或失败模式及平台差异；不逐行复述 JSX 或自解释类型。
- 公共 API、非直观约束和跨平台行为使用简短 JSDoc。HTTP 字段、URL、导航参数和原生属性按外部协议原样命名。

## Commands and verification

Use Node `>=22.11.0` and install with `npm ci`.

```sh
npm start
npm run android
npm run ios
npm run start:web
npm run build:web
npm run format
npm run format:check
npm run lint
npm run typecheck
npm test -- --runInBand
npm run test:android
npm run verify
```

- 行为变化须新增或更新共置的 `*.test.ts(x)`，覆盖正常、边界和错误路径；API 解析、校验、存储和服务逻辑优先测试。
- 每个可回滚阶段结束至少运行 format check、lint、typecheck 和相关 Jest；最终运行 `npm run verify` 与 `git diff --check`。
- 修改原生依赖后在 macOS 运行 `bundle exec pod install`。Windows Android 测试依赖本机有效的 `android/local.properties`，该路径不得提交。
- iOS 构建只能在 macOS 宣称通过；Windows 上必须明确记录未验证。

## Security and configuration

- 从 `src/shared/config/appConfig.ts.template` 创建本机配置。真实 `appConfig.ts` 被忽略，禁止读取后复制、格式化或提交。
- 禁止提交 token、密钥、机器路径、预签名 URL、`dist/`、build、Pods 或 coverage。
- API endpoint、请求/响应结构、token 存储键、上传协议、route name、deep link 和导航参数均视为兼容性接口；结构重构不得顺手改变行为。

## Commits and reviews

- Commit subject 使用简短祈使英文：`Add ...`、`Fix ...`、`Drop ...` 或 `Optimize ...`，每个提交聚焦一个阶段。
- PR 说明用户可见影响、平台差异、验证命令和必要截图；无法在当前平台完成的验证必须明确列出。
- 架构与调试索引见 `docs/architecture.md`；未在行为保持型重构中处理的问题见 `docs/code-review-findings.md`。
