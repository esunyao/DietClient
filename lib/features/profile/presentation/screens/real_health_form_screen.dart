import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diet_ui/diet_ui.dart';

import '../../data/profile_api.dart';
import '../../data/health_fields.dart';
import '../../application/profile_state.dart';
import '../../../../core/session/session_controller.dart';
import '../widgets/health_kind.dart';
import '../widgets/unsaved_form.dart';

class RealHealthFormScreen extends ConsumerStatefulWidget {
  const RealHealthFormScreen({super.key, required this.kind, this.record});
  final String kind;
  final Json? record;
  @override
  ConsumerState<RealHealthFormScreen> createState() => _RealHealthFormState();
}

class _RealHealthFormState extends ConsumerState<RealHealthFormScreen> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _choices = <String, String?>{};
  bool _dirty = false, _saving = false;
  String? _error;
  Object? _session;
  @override
  void initState() {
    super.initState();
    _session = ref.read(sessionProvider);
    for (final field in fieldsByKind[widget.kind] ?? <HealthField>[]) {
      final value = widget.record?[field.key];
      if (field.options != null) {
        _choices[field.key] = value?.toString();
      } else {
        _controllers[field.key] = TextEditingController(
          text: value?.toString() ?? '',
        );
      }
    }
    if (widget.kind == 'measurement' && widget.record == null) {
      _controllers['measuredAt']!.text = DateTime.now()
          .toUtc()
          .toIso8601String();
    }
    if (widget.kind == 'goal' && widget.record == null) {
      _controllers['startedOn']!.text = DateTime.now()
          .toIso8601String()
          .substring(0, 10);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!identical(_session, ref.read(sessionProvider))) {
      setState(() => _error = '账户已切换，请返回重新打开表单。');
      return;
    }
    if (!_form.currentState!.validate()) return;
    final data = <String, dynamic>{};
    for (final field in fieldsByKind[widget.kind]!) {
      if (field.key.endsWith('Code')) {
        data[field.key] =
            widget.record?[field.key] ??
            'custom_${DateTime.now().microsecondsSinceEpoch}';
        continue;
      }
      final value =
          (field.options != null
              ? _choices[field.key]
              : _controllers[field.key]!.text.trim()) ??
          '';
      if (value.isEmpty) {
        if (widget.record?[field.key] != null) {
          setState(() => _error = '已有字段不能通过留空清除，请保留原值。');
          return;
        }
        continue;
      }
      data[field.key] = field.key == 'active'
          ? value == 'true'
          : field.min != null
          ? num.parse(value)
          : value;
    }
    final error = validateHealthDates(widget.kind, data);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(profileApiProvider);
      if (api == null) throw StateError('会话不可用');
      await api.save(
        widget.kind,
        data,
        id: widget.record?[healthIdKeys[widget.kind]]?.toString(),
      );
      if (!mounted || !identical(api, ref.read(profileApiProvider))) return;
      ref.invalidate(healthRecordsProvider(widget.kind));
      setState(() => _dirty = false);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，输入已保留，请重试。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDateTime() async {
    final current =
        DateTime.tryParse(_controllers['measuredAt']!.text)?.toLocal() ??
        DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      _controllers['measuredAt']!.text = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).toUtc().toIso8601String();
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) => UnsavedForm(
    dirty: _dirty,
    child: AppPage(
      title:
          '${widget.record == null ? '添加' : '编辑'}${healthKinds[widget.kind] ?? '健康记录'}',
      showBack: true,
      demoLabel: null,
      subtitle: '保存到你的健康档案；已有字段留空不能清除',
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.red),
              ),
            ),
          AppButton(
            label: _saving ? '保存中…' : '保存记录',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      children: [
        Form(
          key: _form,
          child: AppCard(
            child: Column(
              children: [
                for (final field
                    in fieldsByKind[widget.kind] ?? <HealthField>[])
                  if (!field.key.endsWith('Code'))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: field.dateTime
                          ? ListTile(
                              title: const Text('测量时间'),
                              subtitle: Text(
                                DateTime.tryParse(_controllers[field.key]!.text)
                                        ?.toLocal()
                                        .toString() ??
                                    '选择时间',
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: _saving ? null : _pickDateTime,
                            )
                          : field.options != null
                          ? DropdownButtonFormField<String>(
                              initialValue: _choices[field.key],
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: field.label,
                              ),
                              items: field.options!.entries
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(e.value),
                                    ),
                                  )
                                  .toList(),
                              validator: (v) =>
                                  validateHealthField(field, v ?? ''),
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(() {
                                      _choices[field.key] = v;
                                      _dirty = true;
                                    }),
                            )
                          : TextFormField(
                              controller: _controllers[field.key],
                              enabled: !_saving,
                              maxLines: field.key == 'notes' ? 3 : 1,
                              keyboardType: field.min != null
                                  ? const TextInputType.numberWithOptions(
                                      decimal: true,
                                    )
                                  : TextInputType.text,
                              decoration: InputDecoration(
                                labelText: field.label,
                                hintText: field.date
                                    ? 'YYYY-MM-DD'
                                    : field.dateTime
                                    ? '2026-10-20T12:00:00+08:00'
                                    : null,
                                errorMaxLines: 3,
                              ),
                              validator: (v) =>
                                  validateHealthField(field, v?.trim() ?? ''),
                              onChanged: (_) => setState(() => _dirty = true),
                            ),
                    ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
