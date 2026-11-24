import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/presentation/navigation_manager.dart';
import '../../../../core/session/session_controller.dart';
import '../../application/profile_state.dart';
import '../../data/health_fields.dart';
import '../../data/profile_api.dart';
import '../widgets/health_kind.dart';
import '../widgets/remote_state.dart';

/// 真实健康档案总览页面，为五类记录分别提供独立加载、新增、编辑与删除操作。
class RealHealthRecordsScreen extends ConsumerWidget {
  const RealHealthRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    demoLabel: null,
    title: '健康档案',
    showBack: true,
    subtitle: '身体测量按日期保留；未填写的信息保持未知',
    children: [
      for (final entry in healthKinds.entries)
        _RealHealthCategoryCard(kind: entry.key, label: entry.value),
    ],
  );
}

class _RealHealthCategoryCard extends ConsumerStatefulWidget {
  const _RealHealthCategoryCard({required this.kind, required this.label});

  final String kind;
  final String label;

  @override
  ConsumerState<_RealHealthCategoryCard> createState() =>
      _RealHealthCategoryCardState();
}

class _RealHealthCategoryCardState
    extends ConsumerState<_RealHealthCategoryCard> {
  bool _removing = false;
  String? _error;

  Future<void> _remove(Json record) async {
    final epoch = ref.read(sessionEpochProvider);
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除这条健康记录？',
      content: '删除后无法恢复。',
      confirmLabel: '删除',
    );
    if (!confirmed || !mounted) return;
    if (epoch != ref.read(sessionEpochProvider)) {
      setState(() => _error = '账户已切换，请重新打开记录。');
      return;
    }
    setState(() {
      _removing = true;
      _error = null;
    });
    try {
      final id = record[healthIdKeys[widget.kind]].toString();
      await ref
          .read(profileManagerProvider)
          .deleteHealthRecord(widget.kind, id, epoch: epoch);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiFailure ? error.message : '删除失败，请重试。',
        );
      }
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  void _openForm([Json? record]) => ref
      .read(navigationManagerProvider)
      .openHealthRecordForm(context, widget.kind, record: record);

  String _recordTitle(Json record) =>
      record['allergenName']?.toString() ??
      record['conditionName']?.toString() ??
      record['restrictionName']?.toString() ??
      (record['measuredAt'] == null
          ? null
          : DateTime.tryParse(record['measuredAt'].toString())
                ?.toLocal()
                .toString()) ??
      fieldsByKind['goal']!.first.options?[record['goalType']] ??
      widget.label;

  Widget _buildRecordTile(Json record) => ExpansionTile(
    title: Text(_recordTitle(record)),
    children: [
      for (final field in fieldsByKind[widget.kind]!)
        if (record[field.key] != null && !field.key.endsWith('Code'))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${field.label}：${field.options?[record[field.key].toString()] ?? record[field.key]}',
              ),
            ),
          ),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _removing ? null : () => _openForm(record),
            child: const Text('编辑'),
          ),
          TextButton(
            onPressed: _removing ? null : () => _remove(record),
            child: const Text('删除'),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(onPressed: () => _openForm(), child: const Text('添加')),
          ],
        ),
        if (_error != null) InfoBanner(text: _error!),
        RemoteState(
          value: ref.watch(healthRecordsProvider(widget.kind)),
          retry: () => ref
              .read(profileManagerProvider)
              .refreshHealthRecords(widget.kind),
          builder: (records) => records.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('暂无记录，未填写的信息保持未知。'),
                )
              : ExpansionTile(
                  title: Text('共 ${records.length} 条记录'),
                  subtitle: const Text('展开查看历史与编辑'),
                  children: [
                    for (final record in records) _buildRecordTile(record),
                  ],
                ),
        ),
      ],
    ),
  );
}
