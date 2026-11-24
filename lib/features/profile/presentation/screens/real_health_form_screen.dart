import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/presentation/app_routes.dart';
import '../../../../core/presentation/navigation_manager.dart';
import '../../../../core/session/session_controller.dart';
import '../../application/profile_state.dart';
import '../../data/health_fields.dart';
import '../../data/profile_api.dart';
import '../widgets/health_kind.dart';
import '../widgets/unsaved_form.dart';

/// 真实健康记录新增与编辑表单页面。
class RealHealthFormScreen extends ConsumerStatefulWidget {
  const RealHealthFormScreen({super.key, required this.kind, this.record});

  final String kind;
  final Json? record;

  @override
  ConsumerState<RealHealthFormScreen> createState() =>
      _RealHealthFormScreenState();
}

class _RealHealthFormScreenState extends ConsumerState<RealHealthFormScreen> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _choices = <String, String?>{};
  bool _dirty = false;
  bool _saving = false;
  String? _error;
  late final int _epoch;

  @override
  void initState() {
    super.initState();
    _epoch = ref.read(sessionEpochProvider);
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

  Map<String, dynamic>? _collectRecordPayload() {
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
          return null;
        }
        continue;
      }
      data[field.key] = field.key == 'active'
          ? value == 'true'
          : field.min != null
          ? num.parse(value)
          : value;
    }
    final dateError = validateHealthDates(widget.kind, data);
    if (dateError != null) {
      setState(() => _error = dateError);
      return null;
    }
    return data;
  }

  Future<void> _save() async {
    if (_epoch != ref.read(sessionEpochProvider)) {
      setState(() => _error = '账户已切换，请返回重新打开表单。');
      return;
    }
    if (!_form.currentState!.validate()) return;
    final data = _collectRecordPayload();
    if (data == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(profileManagerProvider)
          .saveHealthRecord(
            widget.kind,
            data,
            id: widget.record?[healthIdKeys[widget.kind]]?.toString(),
            epoch: _epoch,
          );
      if (!mounted || !saved) return;
      setState(() => _dirty = false);
      ref
          .read(navigationManagerProvider)
          .scheduleSafeReturn(
            context,
            fallbackLocation: AppRoutes.healthRecords,
            isValid: () => _epoch == ref.read(sessionEpochProvider),
          );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is ApiFailure
            ? '${error.message}，输入已保留。'
            : '保存失败，输入已保留，请重试。',
      );
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

  void _onChoiceChanged(String key, String? value) {
    setState(() {
      _choices[key] = value;
      _dirty = true;
    });
  }

  void _markDirty(String _) => setState(() => _dirty = true);

  Widget _buildFieldInput(HealthField field) {
    if (field.dateTime) {
      final displayTime =
          DateTime.tryParse(_controllers[field.key]!.text)
              ?.toLocal()
              .toString() ??
          '选择时间';
      return ListTile(
        title: const Text('测量时间'),
        subtitle: Text(displayTime),
        trailing: const Icon(Icons.calendar_today),
        onTap: _saving ? null : _pickDateTime,
      );
    }
    if (field.options != null) {
      return DropdownButtonFormField<String>(
        initialValue: _choices[field.key],
        isExpanded: true,
        decoration: InputDecoration(labelText: field.label),
        items: field.options!.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        validator: (value) => validateHealthField(field, value ?? ''),
        onChanged: _saving
            ? null
            : (value) => _onChoiceChanged(field.key, value),
      );
    }
    return TextFormField(
      controller: _controllers[field.key],
      enabled: !_saving,
      maxLines: field.key == 'notes' ? 3 : 1,
      keyboardType: field.min != null
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.date ? 'YYYY-MM-DD' : null,
        errorMaxLines: 3,
      ),
      validator: (value) => validateHealthField(field, value?.trim() ?? ''),
      onChanged: _markDirty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fields = fieldsByKind[widget.kind] ?? <HealthField>[];
    return UnsavedForm(
      dirty: _dirty,
      busy: _saving,
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
                  for (final field in fields)
                    if (!field.key.endsWith('Code'))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _buildFieldInput(field),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
