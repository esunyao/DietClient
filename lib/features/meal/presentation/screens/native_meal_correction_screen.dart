import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/nutrition/application/nutrition_providers.dart';
import '../../../../core/presentation/app_routes.dart';
import '../../../../core/presentation/navigation_manager.dart';
import '../../../../core/presentation/unsaved_form.dart';
import '../../../../core/session/session_controller.dart';
import '../../application/meal_edit.dart';
import '../widgets/native_meal_widgets.dart';

/// 原生真实餐食修正页，基于共享餐食查询装载并回写菜品或元数据修正。
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
    // 查询刷新或常规令牌续期期间维持当前表单实例不重置用户输入。
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
            retry: () =>
                ref.read(nutritionManagerProvider).refreshMeal(mealId!),
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
  bool _dirty = false;
  bool _itemsChanged = false;
  bool _busy = false;
  String? _error;

  // 仅用于隔离跨账户异步回写结果，不代表取消底层网络请求。
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
      final saved = await ref
          .read(nutritionManagerProvider)
          .saveMealCorrection(
            original: _original,
            mealType: _type,
            consumedAt: date,
            notes: _notes.text,
            itemsChanged: _itemsChanged,
            items: _items.map((i) => i.toInput()).toList(),
            epoch: widget.epoch,
          );
      if (!mounted || saved == null || !_current) return;
      setState(() => _dirty = false);
      ref
          .read(navigationManagerProvider)
          .scheduleSafeReturn(
            context,
            fallbackLocation: AppRoutes.mealDetail(saved.mealId),
            isValid: () => _current,
          );
    } catch (error) {
      if (_current) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _addItem() {
    setState(() {
      _items.add(MealItemEdit());
      _dirty = true;
      _itemsChanged = true;
    });
  }

  void _removeItem(MealItemEdit item) {
    setState(() {
      _items.remove(item);
      _dirty = true;
      _itemsChanged = true;
    });
  }

  @override
  Widget build(BuildContext context) => UnsavedForm(
    dirty: _dirty,
    busy: _busy,
    fallbackLocation: AppRoutes.mealDetail(_original.mealId),
    child: AppPage(
      demoLabel: null,
      title: '修正${mealTypeLabel(_type)}',
      showBack: true,
      footer: AppButton(
        label: _busy ? '正在保存…' : '保存修正',
        onPressed: _busy ? null : _save,
      ),
      children: [
        if (_error != null) InfoBanner(text: _error!),
        _MealMetaCard(
          mealType: _type,
          date: _date,
          timezone: _original.timezone,
          notesController: _notes,
          busy: _busy,
          onTypeChanged: (value) {
            _type = value;
            _changed();
          },
          onPickTime: _pickTime,
          onNotesChanged: () => _changed(),
        ),
        const InfoBanner(text: '保存后更新本餐、当日和趋势统计。修改重量不会自动换算营养，请逐菜核对。'),
        for (final item in _items)
          Padding(
            key: ObjectKey(item),
            padding: const EdgeInsets.only(top: 12),
            child: _MealItemEditCard(
              item: item,
              busy: _busy,
              onChanged: () => _changed(items: true),
              onRemove: () => _removeItem(item),
            ),
          ),
        TextButton(
          onPressed: _busy || _items.length >= 100 ? null : _addItem,
          child: const Text('添加菜品'),
        ),
      ],
    ),
  );
}

class _MealMetaCard extends StatelessWidget {
  const _MealMetaCard({
    required this.mealType,
    required this.date,
    required this.timezone,
    required this.notesController,
    required this.busy,
    required this.onTypeChanged,
    required this.onPickTime,
    required this.onNotesChanged,
  });

  final String mealType;
  final DateTime date;
  final String timezone;
  final TextEditingController notesController;
  final bool busy;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onPickTime;
  final VoidCallback onNotesChanged;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: mealType,
          decoration: const InputDecoration(labelText: '餐别'),
          items: kMealTypeLabels.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: busy
              ? null
              : (value) {
                  if (value != null) onTypeChanged(value);
                },
        ),
        OutlinedButton(
          onPressed: busy ? null : onPickTime,
          child: Text('用餐时间 ${formatLocalDateTimeMinute(date)}'),
        ),
        const Text('时间按设备本地时区显示', style: AppTypography.small),
        Text('保留原记录时区：$timezone', style: AppTypography.small),
        TextField(
          controller: notesController,
          enabled: !busy,
          maxLength: 1000,
          decoration: const InputDecoration(labelText: '本餐备注'),
          onChanged: (_) => onNotesChanged(),
        ),
      ],
    ),
  );
}

class _MealItemEditCard extends StatelessWidget {
  const _MealItemEditCard({
    required this.item,
    required this.busy,
    required this.onChanged,
    required this.onRemove,
  });

  final MealItemEdit item;
  final bool busy;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    // 同时展示常用指标编码和服务端原有额外指标，防止编辑后丢失字段。
    final codes = {...kEditableNutrientLabels.keys, ...item.amounts.keys};
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            initialValue: item.name,
            enabled: !busy,
            decoration: const InputDecoration(labelText: '菜品名称'),
            maxLength: 150,
            onChanged: (v) {
              item.name = v;
              onChanged();
            },
          ),
          TextFormField(
            initialValue: item.weight,
            enabled: !busy,
            decoration: const InputDecoration(labelText: '实际食用量 (g)，未知可留空'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              item.weight = v;
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          const Text('逐菜核对营养。修改重量不会自动推算营养；空白表示未知。', style: AppTypography.small),
          for (final code in codes)
            TextFormField(
              key: ValueKey((item, code)),
              initialValue: item.amounts[code],
              enabled: !busy,
              decoration: InputDecoration(
                labelText:
                    kEditableNutrientLabels[code] ??
                    '${item.original?.nutrients.where((n) => n.nutrientCode == code).firstOrNull?.nutrientName ?? code} ($code)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (v) {
                item.amounts[code] = v;
                onChanged();
              },
            ),
          TextFormField(
            initialValue: item.notes,
            enabled: !busy,
            decoration: const InputDecoration(labelText: '菜品备注'),
            maxLength: 500,
            onChanged: (v) {
              item.notes = v;
              onChanged();
            },
          ),
          TextButton(
            onPressed: busy ? null : onRemove,
            child: const Text('移除此菜品'),
          ),
        ],
      ),
    );
  }
}
