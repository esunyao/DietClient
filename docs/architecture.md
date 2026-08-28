# DietClient 架构与调试索引

## 1. 模块边界

```text
App.tsx / src/navigation
          │ 选择导航树、组合页面
          ▼
src/app/session
          │ 组合认证结果与用户档案
          ▼
src/features/{auth,diet,profile}
          │ 使用通用 HTTP、UI、上传和主题
          ▼
src/shared
```

`shared` 不知道任何业务域；feature 之间不横向导入。跨 auth 与 profile 的 token、用户和首次档案引导由 `app/session` 编排。ESLint 的 `no-restricted-imports` overrides 对这些边界做自动检查。

## 2. 目录职责

- `src/app/session/sessionStore.ts`：登录态、token、用户、档案、头像预览、首次引导和退出。
- `src/app/session/useSessionLifecycle.ts`：启动 hydrate、AppState 前台刷新及监听器释放。
- `src/app/session/tokenStorage/`：内存、Keychain/Keystore 与 Web localStorage 平台实现；存储键和序列化协议集中在此。
- `src/features/*/api/`：本领域 endpoint facade、请求/响应类型及协议解析。
- `src/features/*/screens/`：一个路由页面一个同名文件；页面私有样式共置。
- `src/features/*/components/`：至少复用两处或具有独立交互职责的业务组件。
- `src/features/*/services/`：可测试流程、缓存、上传适配及平台分发入口。
- `src/navigation/`：route name、参数表、Stack/Tab 组合和底栏元数据。
- `src/shared/components/`：layout、primitives、fields、overlays 与 surfaces；业务代码从公共 barrel 导入。
- `src/shared/api/`：Axios、响应 envelope、无损 JSON；通过 adapter 调用 app session，不反向依赖 auth。
- `src/shared/upload/`：原生文件与 Web Blob 的统一 PUT 上传。
- `src/shared/native/`：Fabric Codegen 声明和平台桥接入口，文件名属于原生接口。

## 3. 关键数据流

### App 启动与会话恢复

1. `AppNavigator` 调用 `useSessionLifecycle`。
2. `sessionStore.hydrate` 从平台 token storage 恢复凭证，并立即同步 Axios Bearer header。
3. 顺序读取 `/users/self` 与 profile，避免首次建用户时产生并发竞争。
4. 结合本机 registration marker 判断是否进入首次档案引导。
5. 根导航只根据 `status` 和 `onboardingResolved` 选择 Auth 或 Main 导航树。

定时刷新、回到前台刷新和 HTTP 401 恢复全部进入 `refreshSessionTokens`，同一时间只交换一次 refresh token。`shared/api/client.ts` 只持有 app session 注入的最小 adapter。

### Authentik 登录与注册

页面 → `authApi` facade → Authentik executor challenge → PKCE authorization code 交换 → app session 持久化 token → 顺序加载用户和档案。注册完成先写非敏感 onboarding marker，邮箱验证后再由登录会话消费。

登录与注册共用的字段、页面壳和 challenge 交互位于 `features/auth/components/AuthFlow.tsx`，各 Screen 只保留自身表单规则、提交和导航。

### 饮食识别

`RecognitionScreen` 负责展示和交互，`services/mealCapture` 负责草稿恢复、会话、图片预签名/确认、提交与取消；`shared/upload` 负责二进制 PUT。提交后由 diet API 刷新识别结果与历史数据。平台图片读取保留 `.native/.web` 分发。

### 健康记录

`HealthRecordsScreen` 读取五类摘要；`HealthRecordFormScreen` 处理单类编辑。`healthRecordAdapter.ts` 显式映射五类 ID 与 list API，缓存和页面共同使用，禁止动态 `Record<string, unknown>` 索引。服务端确认 create/update/remove 后再同步本地摘要缓存。

### 头像上传

`features/profile/components/AvatarEditor.tsx` 选择图片 → avatar service 规范化平台文件 → `userApi.createAvatarUpload` 获取预签名信息 → 平台上传实现 PUT → confirm → 刷新用户与可显示 URL。原生 `content://`/`ph://` 与 Web CORS 约束分别留在平台服务中。

## 4. 修改功能时去哪里

| 需求                  | 首要位置                                                               | 同步检查                                           |
| --------------------- | ---------------------------------------------------------------------- | -------------------------------------------------- |
| 登录、注册、challenge | `features/auth/api/authApi.ts`、对应 Auth screen                       | `authTypes.ts`、auth API tests                     |
| token 恢复/刷新/退出  | `app/session/`                                                         | `shared/api/client.ts` adapter、tokenStorage tests |
| 首页数据与快捷入口    | `features/diet/screens/HomeScreen.tsx`                                 | `nutriApi.ts`、navigation types                    |
| 拍照识别与草稿        | `features/diet/screens/RecognitionScreen.tsx`                          | `services/mealCapture/`、shared upload             |
| 历史、详情、修正      | 对应 `Meal*Screen.tsx`                                                 | nutri types/API、mealCorrection service            |
| 档案展示与编辑        | `features/profile/screens/ProfileScreen.tsx` / `EditProfileScreen.tsx` | session store、user API                            |
| 健康记录 CRUD         | `HealthRecordsScreen.tsx` / `HealthRecordFormScreen.tsx`               | healthRecordAdapter、health API/cache              |
| 共享输入/浮层/玻璃    | `shared/components/{fields,overlays,surfaces}`                         | 公共 barrel、平台变体测试                          |
| route name 或参数     | `navigation/types.ts`、`AppNavigator.tsx`                              | deep link、pageRegistry、tab order                 |
| 颜色/间距/字体        | `shared/theme/tokens.ts`                                               | 必须保持现有精确视觉值                             |

## 5. 组件与样式判断

- 只服务一个页面且没有独立状态流程：留在页面文件。
- 至少两个调用点、具有独立状态/错误流程、可独立测试或存在平台变体：抽到 feature component/service。
- 跨业务域仍有稳定语义：才进入 shared。
- React Native 固定样式默认 `StyleSheet.create` 共置；动态尺寸、颜色和 Reanimated 值可留在 JSX style 数组。
- Web 手机外壳的布局 CSS 留在 `web/index.html`，不要迁入 React Native StyleSheet。

## 6. 平台和构建约束

- Metro、Webpack、Jest 和 TypeScript 共同解析相对路径；当前不使用路径别名。
- `.native/.web/.android/.ios` 是平台分发接口，不以减少文件数量为由合并。
- `src/shared/native/*NativeComponent.ts` 是 Codegen 输入；默认导出、组件名和 prop 名可能由框架要求决定。
- Android Glass、snapshot coordinator、picker 以及 iOS capture coordinator 的公开名称与生命周期属于兼容接口。
- Android SDK 路径只存在于本机 `android/local.properties`；iOS 构建与 Pods 验证必须在 macOS 完成。
