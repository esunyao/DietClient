import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/app_routes.dart';
import '../../../../demo/demo_store.dart';
import 'health_kind.dart';

class HealthRecordCategory extends ConsumerStatefulWidget {
  const HealthRecordCategory({
    super.key,
    required this.kind,
    required this.records,
    this.wide = false,
  });

  final String kind;
  final List<HealthRecordPreview> records;
  final bool wide;

  @override
  ConsumerState<HealthRecordCategory> createState() =>
      _HealthRecordCategoryState();
}

class _HealthRecordCategoryState extends ConsumerState<HealthRecordCategory> {
  bool _expanded = false;

  String get _description {
    final latest = latestHealthRecord(widget.records, widget.kind);
    if (latest != null && latest.note.isNotEmpty) return latest.note;
    return switch (widget.kind) {
      'measurement' => '手工记录，可查看历史测量',
      'goal' => '按记录日期保留目标与方向',
      'allergy' => '未填写不等于已确认无过敏',
      'disease' => '未填写不等于已确认无疾病',
      _ => '可补充医疗、宗教或生活方式限制',
    };
  }

  String get _value {
    final latest = latestHealthRecord(widget.records, widget.kind);
    if (latest == null) return widget.kind == 'restriction' ? '暂无记录' : '暂未填写';
    final value = switch (widget.kind) {
      'measurement' => '${latest.value} / ${healthRecordDate(latest.date)}',
      'allergy' => '${latest.title} / ${latest.value}',
      'disease' || 'restriction' => latest.title,
      _ => latest.value,
    };
    return '$value${widget.records.length > 1 ? ' · 共${widget.records.length}条' : ''}';
  }

  Future<void> _remove(HealthRecordPreview record) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这条演示记录？'),
        content: Text('“${record.title}”将从本次预览中移除，重启后恢复样例。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('保留'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (remove == true) {
      ref.read(demoProvider.notifier).removeHealthRecord(record.id);
      if (mounted) showDemoMessage(context, '已从本次演示中移除。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.kind == 'allergy'
        ? AppColors.amberInk
        : AppColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 82),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.wide ? 24 : 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Icon(healthIcons[widget.kind], size: 27, color: color),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final title = Text(
                                healthKinds[widget.kind]!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                              final value = Text(
                                _value,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: widget.kind == 'allergy'
                                      ? color
                                      : AppColors.muted,
                                ),
                              );
                              if (constraints.maxWidth < 230 ||
                                  MediaQuery.textScalerOf(context).scale(14) >
                                      20) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    title,
                                    const SizedBox(height: 4),
                                    value,
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  title,
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.topRight,
                                      child: value,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _description,
                            style: TextStyle(
                              fontSize: widget.wide ? 14 : 12,
                              color: AppColors.muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    RotatedBox(
                      quarterTurns: _expanded ? 1 : 0,
                      child: const Icon(
                        AppIcons.caretRight,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: EdgeInsets.fromLTRB(widget.wide ? 68 : 20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 1),
                if (widget.records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '尚未填写，相关情况保持未知。',
                      style: TextStyle(fontSize: 14, color: AppColors.muted),
                    ),
                  ),
                for (final record in widget.records)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${record.title} · ${record.value}',
                      style: const TextStyle(fontSize: 15),
                    ),
                    subtitle: Text(
                      '${record.date}${record.note.isEmpty ? '' : '\n${record.note}'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                    isThreeLine: record.note.isNotEmpty,
                    trailing: IconButton(
                      tooltip: '删除演示记录',
                      icon: const Icon(
                        AppIcons.trash,
                        color: AppColors.red,
                        size: 22,
                      ),
                      onPressed: () => _remove(record),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        context.push(AppRoutes.healthRecordForm(widget.kind)),
                    icon: const Icon(AppIcons.plus, size: 18),
                    label: Text('添加${healthKinds[widget.kind]}'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
