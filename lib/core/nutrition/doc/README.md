# 共享膳食数据

封装 NutriMemo 用户侧策略、采集会话、图片确认、餐食管理与每日营养汇总。业务请求经配置网关，预签名 PUT 通过独立无认证客户端；不调用 Kafka、HealthMind 内部上下文或模型接口。

响应模型保留餐食、图片和条目精确字符串 ID。营养按后端编码与单位展示，缺失指标保持未知，未知分析状态不解释为成功。查询由 Riverpod 共享，提交、修正、删除及分析完成后集中失效相关查询；写请求不自动重放。

可见且处于前台的待分析页面每 3 秒刷新，单个查询最多 2 分钟。慢请求加载期间跳过重复失效；切换查询重新获得独立窗口，不重建业务页面，离页或后台暂停。超时后提供手动刷新。

设备时区采用成熟插件返回的 IANA 标识，失败明确提示重试。日期筛选使用本地日期，编辑已有记录保留原时区。Android/Windows 页面装配真实能力；Web 保持原有页面和独立演示。

历史照片复用 mealProvider 与 captureSessionProvider，仅收集 confirmed 图片并按 slotNo 排序。MealPhoto 保留精确 imageId、slotNo、可空 previewUrl 与 expiresAt；TTL 从采集响应接收时间计算。MealPhotoSet 的 photos 为只读副本，sessionEpoch 标记所属登录代次，只用于内存隔离，不属于 HTTP 字段。mealPhotosProvider(mealId) 共享元数据，mealPhotoBytesProvider((mealId, imageId)) 共享 Uint8List；界面可分别 invalidate 重试。

照片字节不随分析轮询或签名元数据刷新重新下载。到期或对象 GET 返回 401/403 时，同餐食并发请求合并一次采集会话刷新，每次字节查询最多自动刷新重试一次；刷新失败保留明确错误。字节与签名仅驻留当前账户的活动监听范围内存，无磁盘缓存、无跨页面保活池；最后一个监听者离开后自动释放并取消读取。账户代次变化取消旧对象请求，迟到的餐食、采集元数据和字节均不能发布为当前结果。单图至多 10 MiB，总量随当前活动照片监听数量变化；页面负责限制可见照片监听范围。

[模块导航](../AGENTS.md) · [架构](../../../../doc/architecture.md) · [根规范](../../../../AGENTS.md)
