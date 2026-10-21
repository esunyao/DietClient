import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/nutrition/application/nutrition_providers.dart';
import '../../application/meal_edit.dart';
import '../widgets/native_meal_widgets.dart';

class NativeMealCorrectionScreen extends ConsumerWidget {
  const NativeMealCorrectionScreen({super.key, this.mealId});
  final String? mealId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (mealId == null) {
      return const AppPage(
        demoLabel: null,
        title: '手工记录',
        showBack: true,
        children: [InfoBanner(text: '独立手工新建暂未支持。可拍照记录后，在单餐详情核对并修正。')],
      );
    }
    final epoch = ref.watch(sessionEpochProvider);
    final result = ref.watch(mealProvider(mealId!));
    // Keep the same form across query invalidation and normal token rotation.
    if (result.value case final meal?) {
      return _MealEditForm(
        key: ValueKey((mealId, epoch)),
        original: meal,
        epoch: epoch,
      );
    }
    return AppPage(
      demoLabel: null,
      title: '修正本餐',
      showBack: true,
      children: [
        if (result.isLoading) const Center(child: CircularProgressIndicator()),
        if (result.hasError)
          NutritionError(
            error:
                result.error is ApiFailure &&
                    (result.error as ApiFailure).status == 404
                ? '记录不存在，无法编辑'
                : result.error!,
            retry: () => ref.invalidate(mealProvider(mealId!)),
          ),
      ],
    );
  }
}

class _MealEditForm extends ConsumerStatefulWidget {
  const _MealEditForm({super.key, required this.original, required this.epoch});
  final Meal original;
  final int epoch;
  @override
  ConsumerState<_MealEditForm> createState() => _EditState();
}

class _EditState extends ConsumerState<_MealEditForm> {
  late final Meal _original = widget.original;
  late final _notes = TextEditingController(text: _original.notes ?? '');
  late DateTime _date = _original.consumedAt.toLocal();
  late String _type = _original.mealType;
  late final List<MealItemEdit> _items = _original.items
      .map((i) => MealItemEdit(original: i))
      .toList();
  bool _dirty = false, _itemsChanged = false, _busy = false, _leaving = false;
  String? _error;
  bool get _current =>
      mounted && ref.read(sessionEpochProvider) == widget.epoch;
  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _changed({bool items = false}) => setState(() {
    _dirty = true;
    _itemsChanged |= items;
  });
  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted || !_current) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time == null || !_current) return;
    setState(() {
      _date = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _dirty = true;
    });
  }

  Future<void> _leave() async {
    if (_busy) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存的修改？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('放弃修改'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
    }
  }

  Future<void> _save() async {
    if (_busy || !_current) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final date = _date;
      if (date.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
        throw const FormatException('用餐时间不能晚于当前时间');
      }
      if (_notes.text.length > 1000) {
        throw const FormatException('备注不能超过 1000 字');
      }
      final api = ref.read(nutritionApiProvider);
      if (api == null) throw const ApiFailure('请先登录');
      final Meal saved;
      if (_itemsChanged) {
        if (_items.length > 100) throw const FormatException('最多 100 道菜');
        saved = await api.replaceItems(
          _original.mealId,
          MealCorrection(
            mealType: _type,
            consumedAt: date,
            timezone: _original.timezone,
            notes: _notes.text,
            items: _items.map((i) => i.toInput()).toList(),
          ),
        );
      } else {
        saved = await api.patchMeal(
          _original.mealId,
          mealType: _type,
          consumedAt: date,
          timezone: _original.timezone,
          notes: _notes.text,
        );
      }
      if (!_current) return;
      // The returned server record is authoritative; all linked queries refetch.
      refreshNutrition(ref);
      ref.read(mealProvider(saved.mealId));
      setState(() {
        _dirty = false;
        _leaving = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_current) context.pop();
      });
    } catch (e) {
      if (_current) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _item(MealItemEdit item) {
    const known = {
      'ENERGY_KCAL': '能量 (kcal)',
      'PROTEIN': '蛋白质 (g)',
      'CARBOHYDRATE': '碳水 (g)',
      'FAT': '脂肪 (g)',
      'DIETARY_FIBER': '膳食纤维 (g)',
      'SODIUM': '钠 (mg)',
    };
    final codes = {...known.keys, ...item.amounts.keys};
    return AppCard(
      key: ObjectKey(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            initialValue: item.name,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: '菜品名称'),
            maxLength: 150,
            onChanged: (v) {
              item.name = v;
              _changed(items: true);
            },
          ),
          TextFormField(
            initialValue: item.weight,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: '实际食用量 (g)，未知可留空'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              item.weight = v;
              _changed(items: true);
            },
          ),
          const SizedBox(height: 12),
          const Text('逐菜核对营养。修改重量不会自动推算营养；空白表示未知。', style: AppTypography.small),
          for (final code in codes)
            TextFormField(
              key: ValueKey((item, code)),
              initialValue: item.amounts[code],
              enabled: !_busy,
              decoration: InputDecoration(
                labelText:
                    known[code] ??
                    '${item.original?.nutrients.where((n) => n.nutrientCode == code).firstOrNull?.nutrientName ?? code} ($code)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (v) {
                item.amounts[code] = v;
                _changed(items: true);
              },
            ),
          TextFormField(
            initialValue: item.notes,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: '菜品备注'),
            maxLength: 500,
            onChanged: (v) {
              item.notes = v;
              _changed(items: true);
            },
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _items.remove(item);
                    _dirty = true;
                    _itemsChanged = true;
                  }),
            child: const Text('移除此菜品'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: (!_dirty && !_busy) || _leaving,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_leaving) _leave();
    },
    child: AppPage(
      demoLabel: null,
      title: '修正${mealTypes[_type] ?? _type}',
      showBack: true,
      footer: AppButton(
        label: _busy ? '正在保存…' : '保存修正',
        onPressed: _busy ? null : _save,
      ),
      children: [
        if (_error != null) InfoBanner(text: _error!),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: '餐别'),
                items: mealTypes.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (v) {
                        _type = v!;
                        _changed();
                      },
              ),
              OutlinedButton(
                onPressed: _busy ? null : _pickTime,
                child: Text(
                  '用餐时间 ${nutritionDate(_date)} ${_date.hour.toString().padLeft(2, '0')}:${_date.minute.toString().padLeft(2, '0')}',
                ),
              ),
              const Text('时间按设备本地时区显示', style: AppTypography.small),
              Text('保留原记录时区：${_original.timezone}', style: AppTypography.small),
              TextField(
                controller: _notes,
                enabled: !_busy,
                maxLength: 1000,
                decoration: const InputDecoration(labelText: '本餐备注'),
                onChanged: (_) => _changed(),
              ),
            ],
          ),
        ),
        const InfoBanner(text: '保存后更新本餐、当日和趋势统计。修改重量不会自动换算营养，请逐菜核对。'),
        for (final item in _items)
          Padding(
            key: ObjectKey(item),
            padding: const EdgeInsets.only(top: 12),
            child: _item(item),
          ),
        TextButton(
          onPressed: _busy || _items.length >= 100
              ? null
              : () => setState(() {
                  _items.add(MealItemEdit());
                  _dirty = true;
                  _itemsChanged = true;
                }),
          child: const Text('添加菜品'),
        ),
      ],
    ),
  );
}
