import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/demo/demo_store.dart';

import '../widgets/health_kind.dart';
import '../widgets/unsaved_form.dart';

class HealthRecordFormScreen extends ConsumerStatefulWidget {
  const HealthRecordFormScreen({super.key, required this.kind});
  final String kind;
  @override
  ConsumerState<HealthRecordFormScreen> createState() =>
      _HealthRecordFormScreenState();
}

class _HealthRecordFormScreenState
    extends ConsumerState<HealthRecordFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _value = TextEditingController();
  final _date = TextEditingController();
  final _note = TextEditingController();
  bool _dirty = false;
  String? _measurement;
  String? _savedId;
  @override
  void dispose() {
    for (final c in [_name, _value, _date, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? '请填写此项' : null;
  String? _validDate(String? v) {
    if (_required(v) != null) return '请填写记录日期';
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v!)) return '请输入 YYYY-MM-DD';
    final date = DateTime.tryParse(v);
    if (date == null ||
        date.toIso8601String().substring(0, 10) != v ||
        date.isAfter(DateTime.now())) {
      return '请输入有效的记录日期';
    }
    return null;
  }

  Widget field(
    String label,
    TextEditingController c, {
    String? hint,
    bool numeric = false,
    int lines = 1,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      controller: c,
      maxLines: lines,
      onChanged: (_) => setState(() {
        _dirty = true;
        _savedId = null;
      }),
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      validator: validator ?? _required,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorMaxLines: 3,
      ),
    ),
  );
  void _save() {
    if (!_form.currentState!.validate()) return;
    final id = 'health-${DateTime.now().microsecondsSinceEpoch}';
    final measurement = widget.kind == 'measurement';
    final unit = measurement
        ? RegExp(r'（(.+)）').firstMatch(_measurement!)?.group(1)
        : null;
    ref
        .read(demoProvider.notifier)
        .saveHealthRecord(
          HealthRecordPreview(
            id: id,
            kind: widget.kind,
            title: measurement ? _measurement! : _name.text.trim(),
            value: '${_value.text.trim()}${unit == null ? '' : ' $unit'}',
            note: _note.text.trim(),
            date: _date.text.trim(),
          ),
        );
    FocusScope.of(context).unfocus();
    setState(() {
      _dirty = false;
      _savedId = id;
    });
    showDemoMessage(context, '记录已加入本次演示，返回健康档案可查看。');
  }

  @override
  Widget build(BuildContext context) {
    final label = healthKinds[widget.kind];
    if (label == null) {
      return const AppPage(
        title: '记录类别不可用',
        showBack: true,
        children: [InfoBanner(text: '请返回健康档案，选择支持的记录类别。')],
      );
    }
    final measurement = widget.kind == 'measurement';
    return UnsavedForm(
      dirty: _dirty,
      child: AppPage(
        title: '添加$label',
        subtitle: '新记录为空白，仅保留至本次演示',
        showBack: true,
        footer: AppButton(
          label: _savedId == null ? '保留演示记录' : '本次记录已保留',
          onPressed: _savedId != null ? null : _save,
        ),
        children: [
          Form(
            key: _form,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (measurement) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _measurement,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '测量项目'),
                      items:
                          [
                                '体重（kg）',
                                '身高（cm）',
                                '体脂率（%）',
                                '腰围（cm）',
                                '收缩压（mmHg）',
                                '舒张压（mmHg）',
                                '静息心率（次/分）',
                              ]
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                      validator: (v) => v == null ? '请选择测量项目' : null,
                      onChanged: (v) => setState(() {
                        _measurement = v;
                        _dirty = true;
                        _savedId = null;
                      }),
                    ),
                    const SizedBox(height: 20),
                    field(
                      '测量数值',
                      _value,
                      numeric: true,
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        return n == null || !n.isFinite || n <= 0 || n > 1000
                            ? '请输入大于 0 且不超过 1000 的数值'
                            : null;
                      },
                    ),
                  ] else ...[
                    field(switch (widget.kind) {
                      'goal' => '目标名称',
                      'allergy' => '过敏原',
                      'disease' => '疾病名称',
                      _ => '限制名称',
                    }, _name),
                    field(
                      switch (widget.kind) {
                        'goal' => '目标值或方向',
                        'allergy' => '严重程度与反应',
                        'disease' => '诊断状态',
                        _ => '限制类别与要求',
                      },
                      _value,
                      hint: widget.kind == 'allergy' ? '不明确时填写“待确认”' : null,
                    ),
                  ],
                  field(
                    '记录日期',
                    _date,
                    hint: 'YYYY-MM-DD',
                    validator: _validDate,
                  ),
                  field('备注（可选）', _note, lines: 3, validator: (_) => null),
                ],
              ),
            ),
          ),
          const Text(
            '请用虚构信息体验。记录不替代专业判断；不清楚的情况请写明待确认。',
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.7),
          ),
        ],
      ),
    );
  }
}
