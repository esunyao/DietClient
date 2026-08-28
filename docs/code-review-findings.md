# DietClient 代码审查记录

本文件记录全库审查中发现、但不应在“行为与视觉保持型结构重构”中顺手改变的事项。状态为“已解决”的条目仅表示结构问题已处理，不代表相关产品功能新增。

| ID     | 严重度 | 证据位置                                                          | 风险与建议                                                                                                                                                                                 | 本次状态 |
| ------ | ------ | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- |
| DC-001 | 中     | 原 `features/diet/screens/HomeScreen.tsx`、原 `StaticScreens.tsx` | 教学旧首页无引用，且存在第二个静态 Recognition，容易修改错页面。删除死实现并让路由页面按文件名定位。                                                                                       | 已解决   |
| DC-002 | 低     | 原 `shared/animation/useCountUp.ts`                               | 无调用点，扩大维护和搜索噪音。                                                                                                                                                             | 已解决   |
| DC-003 | 中     | `ReportsScreen.tsx`、`TrendsScreen.tsx`、`ScoreDetailScreen.tsx`  | 固定 2026 日期、评分和演示数据可能被误认为真实产品数据。接入报告服务前应增加明确产品态或替换数据源。                                                                                       | 仅记录   |
| DC-004 | 高     | `jest.config.js`、各 `screens/`                                   | 旧覆盖率 72.49% 未纳入多数页面，不能代表全库质量。增加 `collectCoverageFrom` 后的真实基线为 22.83% statements / 23.29% lines；后续按风险补页面/controller 测试，不先设虚假阈值。           | 部分解决 |
| DC-005 | 阻塞   | 本机 `android/local.properties`                                   | `sdk.dir=D:\\Users\\Esuny\\...` 不存在，JVM 测试无法启动。修复本机 SDK 路径，禁止提交。                                                                                                    | 外部阻塞 |
| DC-006 | 中     | `npm run build:web` 输出                                          | 当前生产 bundle 约 2.09 MiB，Webpack 给出体积警告。行为保持阶段不做拆包；后续用 bundle analyzer 判断 Skia、图标和页面懒加载收益。                                                          | 仅记录   |
| DC-007 | 低     | screens/components 中的十六进制与 rgba                            | 部分颜色绕过 theme token，后续应按“精确值不变”逐步归并，不能批量近似替换造成视觉回归。                                                                                                     | 仅记录   |
| DC-008 | 高     | 原 Health Record 页面与 cache                                     | 使用 `as unknown as Record<string, unknown>` 动态读取五类 ID，字段改名无法由编译器发现。现已集中到显式 typed adapter。                                                                     | 已解决   |
| DC-009 | 中     | 原 ESLint/Prettier 配置                                           | ESLint 扫描 Android build 生成文件且无格式检查门禁。现已排除生成目录，并增加 format、typecheck、verify 和零 warning lint。                                                                 | 已解决   |
| DC-010 | 中     | `RecognitionScreen.tsx`                                           | 页面仍同时承担较多展示与异步控制职责。建议在下一轮有 UI 自动回归保障后，将恢复、上传、提交、取消和刷新收口到可单测 controller。                                                            | 仅记录   |
| DC-011 | 中     | Authentik executor、上传与原生 snapshot 流程                      | 网络重定向、取消、线程与生命周期包含难以在 Windows 全面验证的边界；不得在结构迁移中改变协议或原生公开名称。后续按平台补集成测试和 KDoc。                                                   | 仅记录   |
| DC-012 | 中     | Android/iOS picker implementations                                | NumericPicker 与 WeightPicker 存在相似数值归一化/格式化策略。应先抽纯函数和补 JVM 测试，再修改桥接实现。当前 Android SDK 不可用，暂不搬迁。                                                | 仅记录   |
| DC-013 | 中     | `shared/components/layout.tsx`、`primitives.tsx`                  | AppScreen/ScreenHeader 折叠上下文已与按钮、卡片等 primitives 分开，公共消费名称仍由 barrel 保持。滚动、命中测试和 Reanimated 时序仍需人工回归。                                            | 已解决   |
| DC-014 | 中     | iOS 原生代码与 Podspec                                            | 当前 Windows 环境无法执行 Xcode/Pods 验证，不能宣称 iOS 原生链路通过。                                                                                                                     | 外部验证 |
| DC-015 | 中     | `features/auth/api/authApi.ts`                                    | facade、executor 推进和 PKCE/token 交换仍集中在较大文件。现有协议测试覆盖重定向与 challenge，但在没有端到端 Authentik 环境时继续机械拆分会增加协议回归风险；建议先补模块级契约测试再迁移。 | 仅记录   |

## 后续处理原则

1. 产品数据、视觉、性能和协议行为单独立项，不与纯结构移动混合。
2. 原生重构以 Android JVM 测试可运行、iOS macOS 构建可用为前置条件。
3. Recognition controller 和 Auth API 协议模块先补流程/契约测试，再移动代码。
4. 每个条目解决时更新证据、验证命令和状态，禁止静默删除记录。
