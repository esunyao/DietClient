# AGENT.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概览

**DietClient** — 饮食健康记录 App。**bare React Native 0.86.0 CLI 项目（非 Expo）**，TypeScript，npm，React 19.2.3，Node ≥ 22.11。

代码注释统一用**中文**（项目惯例）。

## 常用命令

```sh
npm start            # Metro（原生开发）
npm run android      # 构建并运行 Android
npm run ios          # 构建并运行 iOS
npm run start:web    # ⭐ Web 调试：webpack dev server，浏览器打开 http://localhost:8080
npm run build:web    # Web 生产构建 → dist/web/
npm run lint         # ESLint
npm test             # Jest（@react-native/jest-preset）
npx tsc --noEmit     # TypeScript 类型检查
```

> 没有真机/模拟器时用 `npm run start:web` 在浏览器调试，页面以 390×844 手机画框居中显示；开 DevTools 设备模式（Ctrl+Shift+M）则全屏并获得真实手机尺寸的 `Dimensions`。

## 架构与入口

- **双入口**：`index.js`（原生，Metro 用）+ `index.web.js`（Web，react-native-web 用）。二者都注册 `App.tsx` 并渲染同一个根组件。
- **`App.tsx`**：根组件 = `SafeAreaProvider` + `HomeScreen`。目前尚未挂载 NavigationContainer 和全局状态 Provider（代码注释标注为待实现）。
- **目录约定**：按 feature 组织，`src/features/<功能>/screens/`。目前只有 `src/features/diet/screens/HomeScreen.tsx`（单文件 500+ 行，含私有子组件）。
- **已安装未使用**：`@react-navigation/*`（路由）、`zustand`（状态）、`axios`（网络）、`react-hook-form`（表单）——后续集成时用，别重复引入新库。

## Web 调试（react-native-web）关键注意事项

这是本项目最容易踩坑的部分，以下问题已实际解决过，改动时不要回退：

1. **babel-loader 的 `exclude` 正则必须用 `[\\/]`**（`web/webpack.config.js`）。Windows 下路径是反斜杠，若写成 `/node_modules\/` 会导致 `webpack-dev-server` 等 `"type": "module"` 的包被 babel 转成 CommonJS、而 webpack 仍按 ESM 解析 → 报 `Uncaught ReferenceError: require is not defined`。
2. **`#root` 必须是 flex 容器**（`web/index.html` 的 CSS `display: flex; flex-direction: column`）。否则 App 内 `SafeAreaView`/`ScrollView` 的 `flex: 1` 无法沿有界高度解析，ScrollView 高度=内容高度 → **无法滚动**（内容被 `overflow: hidden` 裁掉）。
3. **`html, body` 需 `overflow: hidden` + `box-sizing: border-box`**。否则滚轮在画框内滚到底后会**链式传导**带动深色背景和整个画框上下滑动（滚动链）。
4. **`react-dom` 版本必须与 `react` 完全一致（当前 19.2.3）**。react-dom 更高版本（如 19.2.8）的 peer 要求 `react@^19.2.8`，会与项目的 `react@19.2.3` 冲突导致 npm 装不上。
5. 画框尺寸在 `web/index.html` 的 CSS 变量 `--phone-w` / `--phone-h`，改安卓可设 412px / 915px。

## 其他约定

- `babel.config.js` 只用 `module:@react-native/babel-preset`（原生与 web 共用，web 的 `babel-plugin-react-native-web` 仅在 webpack 配置里追加，勿加进根 babel 配置，会破坏原生构建）。
- `metro.config.js` 为默认配置；**勿在 Metro 侧做 web 支持**（RN 0.86 的 Metro 无 web 别名/HTML 壳，官方文档也标注 web 支持为 "undocumented"，web 走 webpack 即可）。
- 构建产物 `dist/` 已加入 `.gitignore`。
