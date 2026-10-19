# 项目总体阅读说明

1. 先读本文件，再读 [公开概览](doc/README.md)。本地存在 [doc-project/README.md](doc-project/README.md) 时按需了解背景与迁移规划；私有层缺失属正常，不阻塞工作。
2. DietClient 是 HealthServer 膳食应用的 Flutter 客户端；React Native 源仓库只作只读参考。行为和 API 以源码、配置、公开契约与测试为准。
3. 根 doc-project 是本地私有背景与规划，不提交；本次用户明确授权写入初始规划。模块 docp 只读、不写入。公开模块说明放 doc/README.md，只讲概要。
4. 根 AGENTS 是规范唯一来源；下层 AGENTS 只提供导航、上下级链接和任务索引。架构、配置、数据结构、接口或行为变化时，同步更新受影响的 doc 与 AGENTS 导航。
5. 参照 HealthServer 的阅读机制，不照搬服务端实现。Orion 提供画像、NutriMemo 管理餐食统计、HealthMind 提供 AI 编排；当前阶段均不接入。

## 范围与边界

- 唯一可写目录：`E:/ProjectSpace/DietClient`。HealthServer、DietClient-ReactNative 和其他兄弟目录只读；不得在其中安装依赖、创建工作树、改动文件或提交。
- 只迁 UI、路由、演示展示与局部交互。不迁 OAuth/Token、HTTP API、真实相机/相册、上传、持久化、AI 请求、推送与权限配置。
- 界面必须标注演示；内存预览不能声称已真实登录、注册、保存、授权或完成分析。
- 主要依据新版需求PPT与C/B端SVG设计，RN仅补充辅助流程。采用新版绿色主题与四项导航；玻璃封装纯Flutter库并提供三档切换与回退，不迁 RN 原生 Android/iOS 实现，不新增 PlatformView/MethodChannel。
- 既有 doc-project 背景正文和 docp 只读。私有层缺失时以本文件、公开 doc、源码继续，不猜测内容。

## 链接树

| 任务 | 入口 |
|---|---|
| 概览、启动、验证 | [README](README.md) → [doc](doc/README.md) |
| 库选择和封装 | [library](doc/library.md) → [pubspec](pubspec.yaml) → [lock](pubspec.lock) |
| 页面迁移范围 | [migration](doc/migration.md) |
| 共享packages | [packages/AGENTS](packages/AGENTS.md) |
| 演示数据 | [demo/AGENTS](lib/demo/AGENTS.md) |
| Dart 源码 | [lib/AGENTS](lib/AGENTS.md) |
| 装配、路由和底栏 | [app/AGENTS](lib/app/AGENTS.md) |
| 主题、组件、UI 偏好 | [core/AGENTS](lib/core/AGENTS.md) |
| 功能页面 | [features/AGENTS](lib/features/AGENTS.md) → feature AGENTS → doc 与源码 |
| 平台宿主 | [Android](android/AGENTS.md) → [Web](web/AGENTS.md)、[Windows](windows/AGENTS.md) |
| 验证 | [test/AGENTS](test/AGENTS.md) → [tool/AGENTS](tool/AGENTS.md) |

## 开发与协作

默认 Git Bash。Dart 使用 UTF-8 无 BOM、dart format、flutter_lints。PowerShell 先设置 UTF-8；不要仅凭终端乱码判断损坏，改写非 ASCII 文件前严格 UTF-8 解码。

存在 .codegraph 时先用 CodeGraph 理解或定位代码；缺失时不主动建索引。多使用确实相关的 skills，先读取技能并说明用途。优先成熟库和标准控件，只在复用语义或复杂能力边界做薄封装。

计划阶段不开子 agent；规划写入 doc-project 后进入实施协作。子 agent 默认 **gpt-6.1-sol / medium**。明确互斥文件归属；共享 checkout 不并发改同一文件、不并发提交。需要 worktree 时只能放本仓库内部忽略目录，分支按 dev/feature-*、dev/doc-* 划分；本轮复用 dev/feature。

依赖方向：main → app → features → core/demo/packages。feature 不横向导入；packages 不依赖应用。共享展示模型放 diet_models，设计系统放 diet_ui，公共演示状态放 demo。统一路径协议位于 core，路由注册位于 app；按需增添真实 data/domain 层，不造空层。一个页面一个文件。

## 验证与提交

见 [tool/verify.sh](tool/verify.sh)：基础格式、静态检查和编译。用户负责功能、视觉、性能验收；不要扩大为完整测试矩阵。Android优先，Web/Windows其次，iOS不纳入本轮。缓存指向本仓库，不升级机器SDK；分别报告实际编译结果。

Conventional Commits：`<type>(<scope>): <简短祈使摘要>`。type 为 feat/fix/docs/refactor/test/chore/build/ci/perf/revert；scope 按 app/core/demo/home/meal-record/meal/meal-plan/trend/report/institution/auth/profile/settings/tool 等职责划分。频繁提交独立可审核变化，精确暂存自身文件，不夹带用户改动，不 push。doc-project/docp、密钥、缓存和截图生成物不提交。

公开文档文件名使用小写英文单数，README.md 除外。CLAUDE.md 若存在，仅两行兼容入口，指向根规范、当前 AGENTS 和本地说明，不维护第二套规范。
