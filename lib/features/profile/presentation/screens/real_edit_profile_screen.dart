import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diet_ui/diet_ui.dart';

import '../../application/profile_state.dart';
import '../../data/profile_api.dart';
import '../../data/health_fields.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/presentation/app_routes.dart';
import '../../../../core/presentation/unsaved_form.dart' show returnOrGo;
import '../widgets/remote_state.dart';
import '../widgets/unsaved_form.dart';

const genderOptions = {
  'male': '男',
  'female': '女',
  'other': '其他',
  'unknown': '未知',
};
const activityOptions = {
  'sedentary': '久坐',
  'light': '轻度活动',
  'moderate': '中度活动',
  'active': '高度活动',
  'very_active': '极高活动',
};

class RealEditProfileScreen extends ConsumerWidget {
  const RealEditProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => RemoteState(
    value: ref.watch(profileProvider),
    retry: () => ref.invalidate(profileProvider),
    builder: (data) =>
        _ProfileForm(key: ValueKey(data['userId']), original: data),
  );
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({super.key, required this.original});
  final Json original;
  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  String? _gender, _activity, _error;
  bool _dirty = false, _saving = false;
  Object? _session;
  @override
  void initState() {
    super.initState();
    _session = ref.read(sessionEpochProvider);
    _fields = {
      for (final key in ['birthDate', 'heightCm', 'dailyWaterTargetMl'])
        key: TextEditingController(
          text: widget.original[key]?.toString() ?? '',
        ),
    };
    _gender = widget.original['gender'] as String?;
    _activity = widget.original['activityLevel'] as String?;
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_session != ref.read(sessionEpochProvider)) {
      setState(() => _error = '账户已切换，请返回重新打开表单。');
      return;
    }
    if (!_form.currentState!.validate()) return;
    final data = <String, dynamic>{};
    for (final entry in _fields.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) {
        if (widget.original[entry.key] != null) {
          setState(() => _error = '已有资料不能通过留空清除，请保留原值。');
          return;
        }
        continue;
      }
      data[entry.key] = entry.key == 'birthDate' ? value : num.parse(value);
    }
    if (_gender != null) data['gender'] = _gender;
    if (_activity != null) data['activityLevel'] = _activity;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(profileApiProvider);
      if (api == null) throw StateError('会话不可用');
      final saved = await api.saveProfile(data);
      if (!mounted ||
          _session != ref.read(sessionEpochProvider) ||
          !identical(api, ref.read(profileApiProvider))) {
        return;
      }
      setState(() => _dirty = false);
      if (!ref
          .read(confirmedProfileProvider.notifier)
          .accept(saved, _session)) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _session == ref.read(sessionEpochProvider) &&
            ModalRoute.of(context)?.isCurrent != false) {
          returnOrGo(context, AppRoutes.profile);
        }
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiFailure
              ? '${error.message}，输入已保留。'
              : '保存失败，输入已保留，请重试。',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String key,
    String label,
    String? Function(String?) validator,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      controller: _fields[key],
      enabled: !_saving,
      decoration: InputDecoration(labelText: label, errorMaxLines: 3),
      validator: validator,
      onChanged: (_) => setState(() => _dirty = true),
    ),
  );
  @override
  Widget build(BuildContext context) => UnsavedForm(
    dirty: _dirty,
    busy: _saving,
    child: AppPage(
      title: '编辑基础资料',
      showBack: true,
      demoLabel: null,
      subtitle: '姓名由账户提供；已有资料留空不能清除',
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
            label: _saving ? '保存中…' : '保存资料',
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
                _field('birthDate', '出生日期（YYYY-MM-DD）', (v) {
                  final value = v?.trim() ?? '';
                  final error = validateHealthField(
                    const HealthField('birthDate', '出生日期', date: true),
                    value,
                  );
                  if (error != null || value.isEmpty) return error;
                  final date = DateTime.parse(value), now = DateTime.now();
                  var age = now.year - date.year;
                  if (now.month < date.month ||
                      (now.month == date.month && now.day < date.day)) {
                    age--;
                  }
                  return age < 10 || age > 120 ? '年龄须在 10–120 岁之间' : null;
                }),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '性别'),
                  items: genderOptions.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (v) => setState(() {
                          _gender = v;
                          _dirty = true;
                        }),
                ),
                const SizedBox(height: 20),
                _field(
                  'heightCm',
                  '身高（cm）',
                  (v) => validateHealthField(
                    const HealthField('heightCm', '身高', min: 50, max: 300),
                    v?.trim() ?? '',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _activity,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '活动水平'),
                  items: activityOptions.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (v) => setState(() {
                          _activity = v;
                          _dirty = true;
                        }),
                ),
                const SizedBox(height: 20),
                _field(
                  'dailyWaterTargetMl',
                  '每日饮水目标（ml）',
                  (v) => validateHealthField(
                    const HealthField(
                      'dailyWaterTargetMl',
                      '饮水目标',
                      min: 0,
                      max: 10000,
                      integer: true,
                    ),
                    v?.trim() ?? '',
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
