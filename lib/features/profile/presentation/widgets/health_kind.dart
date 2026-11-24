import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';

import '../../../../demo/demo_store.dart';

/// 健康记录类别键到中文展示名称的共享映射表。
const healthKinds = {
  'measurement': '身体测量',
  'goal': '健康目标',
  'allergy': '过敏记录',
  'disease': '疾病记录',
  'restriction': '饮食限制',
};

/// 健康记录类别图标映射表。
const healthIcons = {
  'measurement': AppIcons.scales,
  'goal': AppIcons.target,
  'allergy': AppIcons.warning,
  'disease': AppIcons.heartbeat,
  'restriction': AppIcons.prohibit,
};

/// 从记录集合中选出指定类别日期最新的一条记录；无匹配返回 `null`。
HealthRecordPreview? latestHealthRecord(
  Iterable<HealthRecordPreview> records,
  String kind,
) {
  HealthRecordPreview? latest;
  for (final record in records.where((r) => r.kind == kind)) {
    if (latest == null || record.date.compareTo(latest.date) >= 0) {
      latest = record;
    }
  }
  return latest;
}

/// 将健康记录日期文本格式化为“M月D日”展示文案；无法解析时原样返回。
String healthRecordDate(String value) {
  final date = DateTime.tryParse(value);
  return date == null ? value : '${date.month}月${date.day}日';
}

/// 个人中心单行条目展示组件。
class ProfileEntryRow extends StatelessWidget {
  const ProfileEntryRow({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.value,
    this.color = AppColors.primary,
  });

  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  final String? subtitle;
  final String? value;
  final Color color;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value!,
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(
                AppIcons.caretRight,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
