import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/demo/demo_store.dart';

import '../widgets/unsaved_form.dart';
import '../../../../core/config/ui_preview_config.dart';
import 'real_edit_profile_screen.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final PersonProfile _original;
  late final Map<String, TextEditingController> _fields;
  bool _dirty = false;
  @override
  void initState() {
    super.initState();
    _original = ref.read(demoProvider).profile;
    _fields = {
      '昵称': TextEditingController(text: _original.name),
      '出生日期': TextEditingController(text: _original.birthday),
      '身高（cm）': TextEditingController(text: formatAmount(_original.height)),
      '每日饮水目标（ml）': TextEditingController(text: '${_original.waterGoal}'),
    };
    _gender = _original.gender;
    _activity = _original.activity;
  }

  late String _gender;
  late String _activity;
  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate(String key, String? value) {
    if (value == null || value.trim().isEmpty) return '请填写$key';
    if (key == '出生日期') {
      final parts = value.replaceAll('.', '-').split('-');
      if (parts.length != 3) return '请输入 YYYY-MM-DD';
      final y = int.tryParse(parts[0]),
          m = int.tryParse(parts[1]),
          d = int.tryParse(parts[2]);
      if (y == null || m == null || d == null) return '请输入有效日期';
      final date = DateTime(y, m, d);
      if (date.year != y ||
          date.month != m ||
          date.day != d ||
          date.isAfter(DateTime.now()) ||
          y < 1900) {
        return '请输入有效出生日期';
      }
    }
    if (key.contains('cm') &&
        ((double.tryParse(value) ?? 0) < 50 ||
            (double.tryParse(value) ?? 0) > 250)) {
      return '身高应为 50–250 cm';
    }
    if (key.contains('ml') &&
        ((int.tryParse(value) ?? -1) < 100 ||
            (int.tryParse(value) ?? 99999) > 10000)) {
      return '请输入 100–10000 的整数';
    }
    return null;
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    ref
        .read(demoProvider.notifier)
        .updateProfile(
          _original.copyWith(
            name: _fields['昵称']!.text.trim(),
            birthday: _fields['出生日期']!.text.trim(),
            gender: _gender,
            height: double.parse(_fields['身高（cm）']!.text),
            activity: _activity,
            waterGoal: int.parse(_fields['每日饮水目标（ml）']!.text),
          ),
        );
    FocusScope.of(context).unfocus();
    setState(() => _dirty = false);
    showDemoMessage(context, '基础资料已用于本次演示，重启后恢复样例。');
  }

  @override
  Widget build(BuildContext context) => !ref.watch(uiPreviewProvider)
      ? const RealEditProfileScreen()
      : UnsavedForm(
          dirty: _dirty,
          child: AppPage(
            title: '编辑基础资料',
            subtitle: '仅用于本次演示，不会上传或持久保存',
            showBack: true,
            footer: AppButton(label: '保留本次演示修改', onPressed: _save),
            children: [
              Form(
                key: _form,
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in _fields.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: TextFormField(
                            controller: entry.value,
                            onChanged: (_) => setState(() => _dirty = true),
                            validator: (v) => _validate(entry.key, v),
                            keyboardType:
                                entry.key.contains('cm') ||
                                    entry.key.contains('ml')
                                ? const TextInputType.numberWithOptions(
                                    decimal: true,
                                  )
                                : TextInputType.text,
                            decoration: InputDecoration(
                              labelText: entry.key,
                              errorMaxLines: 3,
                            ),
                          ),
                        ),
                      DropdownButtonFormField<String>(
                        initialValue: _gender,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '性别'),
                        items: ['女', '男', '其他', '未说明']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          _gender = v!;
                          _dirty = true;
                        }),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        initialValue: _activity,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '活动水平'),
                        items: ['久坐', '轻度活动', '中度活动', '活跃', '高强度活动']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          _activity = v!;
                          _dirty = true;
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const Text(
                '身体测量请在健康档案中单独添加。修改基础资料不会覆盖测量记录；饮水目标为用户设置，不是统一医学建议。',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.7,
                ),
              ),
            ],
          ),
        );
}
