# 项目总体阅读说明

> [!important]
>
> 1. 先了解整个项目背景、项目意图、项目意义、项目目的、研究背景与未来拓展性。
>
> 2. 必须秉持严谨态度，辩证地看待介绍文件；涉及行为、接口、配置和安全结论时以源码、配置、公开契约和测试证据为准。
>
> 3. 文档按位置各司其职，必须区分：
>    > [!note]
>    >
>    > `<模块>/doc/`：仓库公开的模块大体说明，供 AI 与一般读者快速建立认知，**不展开细节**。
>    >
>    > `<模块>/docp/`：全称 `doc-personal`，本地私有的子项目详细说明；AI **只读参考，不写入**。
>    >
>    > 根 `doc-project/`：特例，专门说明项目整体背景，本地私有，不提交。
>
> 4. 缺少项目背景时，先阅读根 `doc-project/`；缺少模块细节时，再按需阅读对应 `docp/`。
>
> 5. `docp/` 可帮助快速理解设计，但不能替代对当前源码和配置的关键事实核验。
>
> 6. 模块接口、配置、数据结构、架构或行为发生变化时，同步更新受影响模块的 `doc/`。
>
> 7. 继续阅读本文件其余章节。


## 范围与边界

- 唯一可写目录：`E:/ProjectSpace/DietClient`。HealthServer、DietClient-ReactNative 和其他兄弟目录只读；不得在其中安装依赖、创建工作树、改动文件或提交。
- 本轮在已完成的「我的」基础上，将 Android/Windows 采集、餐食、首页、趋势、注册、邮件重发、会话续期与设置接入真实能力。姓名只读。无公开接口的配餐、报告、机构同步和独立手工新建显示暂未支持，不模拟服务器写入。保持绿色视觉、现有玻璃和四项导航；不新增推送。
- Web 新功能留待下轮，保留既有登录、资料与显式 `WEB_UI_PREVIEW=true` 的独立未登录演示；预览不构造会话或业务请求。真实账户缺失资料保持未知或空态，不用样例补齐；未设置营养目标不套用演示目标。图片选择、裁剪与存储使用成熟插件，Android 支持系统相机，Windows 按插件能力选图。
- 视觉依据为 `20261002ui二次设计` 的 C/B 端最终 SVG、设计说明与用户提供的手机个人首页、平板机构首页两张目标图；新版需求 PPT 补充业务语义，React Native 仅辅助未绘流程，不照搬旧主题和六项导航。可复核目标见 [UI 规格](doc/ui-spec.md)。
- 采用新版绿色主题和首页、配餐、趋势、我的四项导航。个人/机构模式显式选择，不由窗口尺寸推断。业务内存预览须清楚标注演示，不能声称已真实注册、保存业务记录、授权 AI 或完成分析。
- 玻璃沿用纯 Flutter 库和关闭/标准/增强三档及能力、无障碍回退；主要用于导航与必要浮层。保留 Windows 背景捕获和状态稳定性，不迁 RN 原生实现，不新增 PlatformView、MethodChannel 或 WebView，不把 Web 磨砂称为实时折射。
- 真实配置继续经本地忽略的 `.env` 与 `--dart-define-from-file` 注入，不读取真实配置；公开 `.env.example` 使用不可连接占位符、client ID 留空。凭据、Cookie、协议参数和 Token 不写日志；密码不持久化。仅用户勾选记住登录时，将刷新令牌及必要身份上下文存入系统安全存储，非敏感外观偏好另存；不持久化业务健康数据、图片或签名 URL。平台与协议边界见 [登录说明](doc/authentication.md)，仅在校验完成后确认登录。
- 本文件「项目总体阅读说明」一节逐字保留。`doc-project/` 历史正文是审计记录，只读、不追改；新行为与新决策另建文件，只有 `README.md` 可更新导航。`docp/` 始终只读参考、不写入；两类私有文档均不提交。

## 文档位置与命名

| 位置 | 职责 |
|---|---|
| 根 `AGENTS.md` | 仓库规范的唯一来源及文档链接树根 |
| 下层 `AGENTS.md` | 只导航：读什么、职责边界、公开说明、源码与回归入口，不复制或新增规范 |
| 根或模块 `doc/README.md`、主题文档 | 公开大体说明；受影响的架构、配置与行为变化同步更新，不展开私有设计细节 |
| 根 `doc-project/` | 本地私有背景、历史规划与审计记录；新行为新文件，README 维护导航 |
| 模块 `docp/` | 维护者本地详细说明，只读参考 |
| `CLAUDE.md`（若存在） | 两行兼容入口，指向根规范、当前 AGENTS 和本地说明，不维护第二套规则 |

公开文档文件名使用小写英文单数，不加日期或版本前缀，`README.md` 是固定例外。只在有独立职责或关键入口时增设导航，不按目录层级机械铺设 `AGENTS.md`。

## 阅读导航

先理解项目背景与依赖框架，再按任务读取必要文件，不以通读全仓作为动手前提。路径为根 `AGENTS.md` → 目标模块 `AGENTS.md` → 模块 `doc/README.md`、源码与聚焦回归。

| 任务 | 入口 |
|---|---|
| 首次了解项目 | 本文件「项目总体阅读说明」→ [本地 doc-project/README.md](doc-project/README.md)（私有）→ [公开文档导航](doc/AGENTS.md) → [公开概览](doc/README.md) |
| 启动与实际验证记录 | [README](README.md) → [tool/AGENTS](tool/AGENTS.md) |
| UI 几何、字阶与安全区目标 | [UI 规格](doc/ui-spec.md) → [diet_ui/AGENTS](packages/diet_ui/AGENTS.md) |
| 库选择和封装 | [library](doc/library.md) → [pubspec](pubspec.yaml) → [lock](pubspec.lock) |
| 架构与页面迁移范围 | [architecture](doc/architecture.md) → [migration](doc/migration.md) |
| Dart 源码 | [lib/AGENTS](lib/AGENTS.md) |
| 装配、路由和导航外壳 | [app/AGENTS](lib/app/AGENTS.md) |
| 配置、会话、路径和 UI 偏好 | [core/AGENTS](lib/core/AGENTS.md) |
| 共享业务演示状态 | [demo/AGENTS](lib/demo/AGENTS.md) |
| 功能页面 | [features/AGENTS](lib/features/AGENTS.md) → feature AGENTS → doc 与源码 |
| 共享模型、设计系统和登录包 | [packages/AGENTS](packages/AGENTS.md) |
| 保留既有真实登录 | [登录说明](doc/authentication.md) → [auth/AGENTS](lib/features/auth/AGENTS.md) |
| 平台宿主 | [Android](android/AGENTS.md)、[Web](web/AGENTS.md)、[Windows](windows/AGENTS.md) |
| 聚焦回归与工具 | [test/AGENTS](test/AGENTS.md) → [tool/AGENTS](tool/AGENTS.md) |

私有 `doc-project/` 或 `docp/` 在新克隆、CI、其他机器上缺失属正常情况，不阻塞工作；改读本文件、公开 `doc/`、当前源码、配置与测试，不猜测私有内容。目标规格不等于已完成或已验收，实际结果另记。

## 开发与协作

默认 Git Bash。Dart 使用 UTF-8 无 BOM、dart format、flutter_lints。PowerShell 先设置 UTF-8；不要仅凭终端乱码判断损坏，改写非 ASCII 文件前严格 UTF-8 解码，尽量保留原编码。

存在 `.codegraph/` 时先用 CodeGraph 理解或定位代码；缺失时不主动建索引。按需使用确实相关且可用的 skills，先读取并说明用途，不假称调用不可用工具。本轮允许新增已批准的偏好、安全存储、时区及必要直接依赖，不升级无关锁定依赖；优先成熟库、Flutter 标准控件和薄封装，用实际约束与逻辑尺寸 tokens 校准布局，不引入 ScreenUtil 式全局缩放，不关闭系统文字缩放。

计划阶段禁止子 agent；批准后先将新规划落入 `doc-project/`。本轮基础阶段完成共享契约后，最多三个 **gpt-6.1-sol / medium** 子 agent 分工实施，不再派生子 agent；主 agent 审查、集成和拆分提交。当前实施分支以 git 实际状态为准，不自动切换。明确互斥文件归属，不并发改同一文件、不并发提交。工作树仅放本仓库忽略目录 `.worktrees/`，分支使用 `dev/feature-*` 或 `dev/doc-*`，不在兄弟仓库建工作树。

依赖方向：main → app → features → core/demo/packages。feature 不横向导入；packages 不依赖应用。共享展示模型放 diet_models，设计系统放 diet_ui，业务演示状态放 demo。diet_oidc 是不依赖 Authentik、Flutter、Riverpod、Cookie 的纯 Dart 通用协议包；diet_auth 是依赖 diet_oidc 的纯 Dart Authentik Flow Executor，使用 Dio 内存 Cookie。应用 core/config 装配配置，core/session 保留内存会话，auth/application 控制登录；Web 平台差异由协议包条件导出隔离。统一路径协议位于 core，路由注册位于 app；本轮沿用现有层次，不造空 data/domain/repository 层、不机械搬文件。一个页面一个文件，feature 内复用放本 feature 的 widgets。

## 验证与提交

验证入口见 [tool/AGENTS](tool/AGENTS.md) 与 [tool/verify.sh](tool/verify.sh)，不把完整脚本矩阵当作本轮默认任务。统一做基础格式、一次静态分析、受影响的聚焦回归和必要的一次 Web 或 Windows 编译；不建立逐页 golden 或全平台矩阵。Android 构建与真机验证由用户负责，iOS 不纳入本轮。

只用 `tool/` 的既有 SDK 与缓存入口，缓存限于本仓库。SDK 由用户自行管理，不自动下载、更换或升级。分别报告实际执行、失败与跳过的检查；功能、视觉和性能由用户验收，编译成功不等于视觉验收，离线测试或公开探测也不能替代真实登录验证。目标规格见 [UI 规格](doc/ui-spec.md)，实际命令与结果在 [README](README.md) 和交付说明记录。

Conventional Commits：`<type>(<scope>): <简短祈使摘要>`。type 为 feat/fix/docs/refactor/test/chore/build/ci/perf/revert；scope 按 app/core/demo/diet-ui/home/meal-record/meal/meal-plan/trend/report/institution/auth/profile/settings/tool 等职责划分。经授权后由主 agent 频繁提交独立可审核变化，精确暂存自身文件，不夹带用户改动，不 push。doc-project/docp、密钥、缓存和截图生成物不提交。
