# 绿色设计系统

以手机 C 端与平板 B 端最终样板的浅绿画布、深绿强调和实体卡片为基础，提供主题、页面、导航、表单外观、状态提示、图表与响应式布局。公开入口为 [diet_ui.dart](../lib/diet_ui.dart)，目标几何见 [视觉规格](../../../doc/ui-spec.md)。尺寸为 Flutter 逻辑像素，不按 2 倍 PNG 缩放，不替换系统 TextScaler。

[包导航](../AGENTS.md) · [库选择](../../../doc/library.md) · [根规范](../../../AGENTS.md)

## 页面与布局

AppLayout 集中维护手机左右24、宽屏左右32、栏距24、840导航断点和1194最大页面宽度；AdaptiveColumns 根据自身可用约束在960及以上分双栏，等价于原1024窗口扣除两侧32。双栏按754:352分配，窄容器仍合为单栏，不因屏幕宽就强塞双栏。AppTypography 提供主标题28、二级标题23、区块19、正文14–16、辅助12–13与主数值39。

AppPage 保留 title、subtitle、children、trailing、showBack、footer，支持局部 titleStyle/mobileGutter（个人首页24号与20边距），新增 eyebrow（标题上方说明）与 demoLabel（默认“设计样例 · 演示数据”，传null隐藏）。手机二级页标题23居中，左侧返回保留44命中区；平板页标题28，右侧 demoLabel 与 trailing 纵排。常规高度标题和 footer 固定，业务 ListView 独立滚动，不再插入额外科学图标提示行。按实际可用高度扣除顶部导航覆盖量后不足随系统文字缩放的300时，标题与 footer 并入同一 ListView，顶部导航覆盖区仍留在滚动区外；字段可完整滚入视口，footer 可滚动触达。键盘开闭及高度模式切换保持业务子项槽位与 Scrollable，不重挂载内部表单和字段。页面统一消费系统安全区；AppPageScope.topInset/bottomInset 只表示导航覆盖量，不包含系统安全区，onLogout 可选回调由应用传入，包不处理会话。没有 footer 时，列表底部一次预留安全区及导航覆盖；有 footer 时，安全区由外层 SafeArea 消费，不重复加入列表与 footer。

AppBottomNavigation 和 AppTopNavigation 只负责展示与选中回调，不依赖应用路由。手机岛完整最大340×58、收紧248×48、迷你184×44；公开 AppNavigationState 对应三态，连续进度先淡出文字再收窄。当前泡横拖跟手预览，抬起/取消以150ms吸附；迷你首手势仅展开。最小44触控，纯图标仍有语义与键盘选择；宽屏使用横向文字 tab。底栏文本按系统 TextScaler 测量增长，顶部导航高度同步增长，应用使用相同高度预留覆盖区。

## 卡片与标准控件

AppCard 以圆角 Material 承载底色与边框，支持 ListTile、AppListRow 和 SwitchListTile 的背景与 ink 交互；保持零阴影、无表面染色及圆角裁剪。padding 仍包含原卡片额外1px边框内缩，radius 默认20，可显式传16用于列表或平板。聚焦回归见 [卡片测试](../../../test/app_card_material_test.dart)。

AppListRow 仍薄封装标准 ListTile，可用 dense 和 contentPadding 控制列表密度。SectionHeading 使用19号标题与至少44高操作。AppBadge 使用圆角8，默认13号字，compact 对应手机紧凑状态。按钮保持标准 FilledButton/OutlinedButton 的语义、禁用和至少44高触控行为，不固定文字高度。AppSegmented 默认保留 ChoiceChip；equalWidth 使用浅绿轨道与白色选中，selectedFilled 改为深绿选中；窄屏或大字时按实际文字宽度换行。

NutritionBarChart 沿用 fl_chart，height 默认210，highlightLast、showValueLabels、missingLabels 均为可选增强。缺失标识可区分“未记录”和“待补充”，不补零；柱顶数字放不下时隐藏，tooltip 与整段语义仍提供数值，页面保留逐日表。图表高度随字体增长，不裁掉日期与缺失文字。

## 玻璃效果

GlassBackdrop 将真实 background 与 overlay 分开装配，第三方类型只留在包内。Android Impeller 保持实时镜片；Windows Skia 捕获单次装配的背景，增强且 shader 成功后以 pixelRatio 1、同步 high（约60fps）持续更新。标准、关闭、高对比与减少透明度停止持续捕获；库首次挂载仍可能初始化捕获一次。增强运动泡仅使用 liquid_glass_easy 5.0.0 公共 LiquidGlassMotionPill，并等待 shader 成功；失败与其他档沿用相同手势及浅绿回退。shader 失败回退磨砂，关闭与无障碍使用实体；Web 保持磨砂，不冒称折射。Windows 容器跨档位稳定，保留页面状态。应用偏好由 core 管理，包本身不接入原生权限、网络或业务状态。

## 图标兼容边界

Flutter 3.47 的 IconData 为 final，而 phosphor_flutter 2.1.0 的 Dart 图标类继承 IconData。AppIcons 使用核对过的上游 Regular 字体码点和标准 const IconData；依赖包仍提供字体资源与许可。页面只使用 AppIcons，不直接导入旧图标类，不修改依赖缓存。新增手工、历史、档案、餐碗、设置、退出与箭头图标仍来自同一字库。

本说明描述组件契约；格式化或编译通过不代表已完成手机、平板或大字视觉验收。
