# 首页内部组件

[根规范](../../../../../AGENTS.md) · [上级](../../AGENTS.md) · [首页说明](../../doc/README.md)

- [personal_home_content.dart](personal_home_content.dart)：个人记录入口、快捷入口与宽屏安排。
- [institution_home_content.dart](institution_home_content.dart)：机构主栏、晚餐/报告/隐私侧栏与次级采集。
- [home_summary.dart](home_summary.dart)：两种体验共享的营养摘要、餐食展示与数字格式。
- [seven_day_summary.dart](seven_day_summary.dart)：基于共享趋势的紧凑摘要，缺失日不补零；逐日值可经提示或趋势页查看。

只做首页展示与既有路由/内存操作，不横向导入其他 feature，不新增业务状态或数据来源。
