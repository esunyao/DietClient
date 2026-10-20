# 资料数据

对齐 Orion self/profile、头像和健康记录公开契约。五类记录为身体测量、健康目标、过敏、疾病、饮食限制；ID 始终使用字符串。PATCH 的 null 表示保留，表单不能宣称清空旧字段。

头像只接受 5 MiB 内 JPEG/PNG/WebP，最多 2500 万像素；方向归一化、最长边 2048 后交给裁剪库，最终编码为 512×512 PNG。用户确认后才执行 presign、无 Bearer/Cookie PUT、JSON 字符串 objectKey confirm。

同意只追加，类型 ai_nutrition_analysis、政策 1.0。按时间再精确 ID 选最新；版本不一致显示需确认。

[数据导航](../AGENTS.md) · [根规范](../../../../../AGENTS.md)
