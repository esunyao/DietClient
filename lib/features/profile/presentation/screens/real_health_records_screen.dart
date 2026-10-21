import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diet_ui/diet_ui.dart';

import '../../application/profile_state.dart';
import '../../data/profile_api.dart';
import '../../data/health_fields.dart';
import '../../../../core/session/session_controller.dart';
import '../widgets/health_kind.dart';
import '../widgets/remote_state.dart';
import 'real_health_form_screen.dart';

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
        _Category(kind: entry.key, label: entry.value),
    ],
  );
}

class _Category extends ConsumerStatefulWidget {
  const _Category({required this.kind, required this.label});
  final String kind, label;
  @override
  ConsumerState<_Category> createState() => _CategoryState();
}

class _CategoryState extends ConsumerState<_Category> {
  bool _removing = false;
  String? _error;
  Future<void> _remove(Json record) async {
    final session = ref.read(sessionEpochProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除这条健康记录？'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (session != ref.read(sessionEpochProvider)) {
      setState(() => _error = '账户已切换，请重新打开记录。');
      return;
    }
    setState(() {
      _removing = true;
      _error = null;
    });
    try {
      final api = ref.read(profileApiProvider);
      if (api == null) throw StateError('会话不可用');
      await api.remove(
        widget.kind,
        record[healthIdKeys[widget.kind]].toString(),
      );
      if (mounted && identical(api, ref.read(profileApiProvider))) {
        ref.invalidate(healthRecordsProvider(widget.kind));
      }
    } catch (_) {
      if (mounted) setState(() => _error = '删除失败，请重试。');
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  void _edit([Json? record]) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => RealHealthFormScreen(kind: widget.kind, record: record),
    ),
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
            TextButton(onPressed: () => _edit(), child: const Text('添加')),
          ],
        ),
        if (_error != null) InfoBanner(text: _error!),
        RemoteState(
          value: ref.watch(healthRecordsProvider(widget.kind)),
          retry: () => ref.invalidate(healthRecordsProvider(widget.kind)),
          builder: (records) => records.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('暂无记录，未填写的信息保持未知。'),
                )
              : ExpansionTile(
                  title: Text('共 ${records.length} 条记录'),
                  subtitle: const Text('展开查看历史与编辑'),
                  children: [
                    for (final record in records)
                      ExpansionTile(
                        title: Text(
                          record['allergenName']?.toString() ??
                              record['conditionName']?.toString() ??
                              record['restrictionName']?.toString() ??
                              (record['measuredAt'] == null
                                  ? null
                                  : DateTime.tryParse(
                                      record['measuredAt'].toString(),
                                    )?.toLocal().toString()) ??
                              fieldsByKind['goal']!
                                  .first
                                  .options?[record['goalType']] ??
                              widget.label,
                        ),
                        children: [
                          for (final field in fieldsByKind[widget.kind]!)
                            if (record[field.key] != null &&
                                !field.key.endsWith('Code'))
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
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
                                onPressed: _removing
                                    ? null
                                    : () => _edit(record),
                                child: const Text('编辑'),
                              ),
                              TextButton(
                                onPressed: _removing
                                    ? null
                                    : () => _remove(record),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
        ),
      ],
    ),
  );
}
