# 业务网络导航

[根规范](../../../AGENTS.md) · [Core](../AGENTS.md) · [说明](doc/README.md)

- [API 客户端](api_client.dart)：当前会话 Bearer、固定相对路径、错误与会话隔离。
- [无损 ID 解码](lossless_json.dart)：响应先接收原文，再保护健康、同意、餐食、条目与图片 Long ID。
- [独立上传](object_upload.dart)：预签名 PUT、所需请求头、取消和进度，不附业务 Bearer/Cookie。
- [配置](../config/api_config.dart)；[资料接口](../../features/profile/data/profile_api.dart)。
- [膳食接口与共享查询](../nutrition/AGENTS.md)；[会话续期](../session/AGENTS.md)。
