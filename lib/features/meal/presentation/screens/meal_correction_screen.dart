import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/core/presentation/app_routes.dart';
import 'package:diet_client/demo/demo_store.dart';

import '../widgets/meal_widgets.dart';

class MealCorrectionScreen extends ConsumerStatefulWidget {
  const MealCorrectionScreen({super.key, this.mealId});
  final String? mealId;
  @override
  ConsumerState<MealCorrectionScreen> createState() =>
      _MealCorrectionScreenState();
}

class _FoodDraft {
  _FoodDraft(this.id, String name, String grams)
    : name = TextEditingController(text: name),
      grams = TextEditingController(text: grams);
  final String id;
  final TextEditingController name;
  final TextEditingController grams;
  void dispose() {
    name.dispose();
    grams.dispose();
  }
}

class _MealCorrectionScreenState extends ConsumerState<MealCorrectionScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _nutrients = <String, TextEditingController>{
    for (final code in ['energy', 'protein', 'carbs', 'fat', 'fiber', 'sodium'])
      code: TextEditingController(),
  };
  final _foods = <_FoodDraft>[];
  MealEntry? _original;
  MealType? _type;
  late DateTime _date;
  bool _dirty = false;
  bool _leaving = false;
  bool _saving = false;
  bool _foodChanged = false;
  bool _extraNutrients = false;
  bool _sampleApplied = false;
  bool get _isNew => widget.mealId == null;
  @override
  void initState() {
    super.initState();
    _original = widget.mealId == null
        ? null
        : ref.read(demoProvider).meal(widget.mealId!);
    _date =
        _original?.consumedAt ??
        DateTime(demoDate.year, demoDate.month, demoDate.day, 12);
    _type = _original?.type;
    _title.text = _original?.title ?? '';
    _notes.text = _original?.notes ?? '';
    if (_original case final original?) {
      for (final food in original.foods) {
        _foods.add(_FoodDraft(food.id, food.name, formatAmount(food.grams)));
      }
      for (final code in _nutrients.keys) {
        final value = original.nutrients.value(code);
        _nutrients[code]!.text = value == null ? '' : formatAmount(value);
      }
      _extraNutrients =
          original.nutrients.fiber != null || original.nutrients.sodium != null;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    for (final c in _nutrients.values) {
      c.dispose();
    }
    for (final food in _foods) {
      food.dispose();
    }
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);
  void _invalidateNutrition() {
    setState(() {
      _dirty = true;
      _foodChanged = true;
      _sampleApplied = false;
      for (final c in _nutrients.values) {
        c.clear();
      }
    });
  }

  String? _number(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final number = double.tryParse(value);
    return number == null || !number.isFinite || number < 0
        ? '请输入有效的非负数值'
        : null;
  }

  Future<void> _changeDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (!mounted) return;
    setState(() {
      _date = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _date.hour,
        time?.minute ?? _date.minute,
      );
      _dirty = true;
    });
  }

  Future<void> _confirmLeave() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('此编辑草稿尚未更新记录，放弃后不会保存。'),
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
    if (discard == true && mounted) {
      setState(() => _leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
    }
  }

  void _applySample() {
    setState(() {
      _foods.firstWhere((f) => f.id == 'fish').grams.text = '120';
      for (final code in _nutrients.keys) {
        _nutrients[code]!.text = '';
      }
      _nutrients['energy']!.text = '620';
      _nutrients['protein']!.text = '26';
      _nutrients['carbs']!.text = '86';
      _nutrients['fat']!.text = '19.6';
      _notes.text = '鱼实际吃了约120 g，其余份量不变';
      _sampleApplied = true;
      _foodChanged = true;
      _dirty = true;
    });
  }

  bool get _canSample =>
      _original?.id == 'lunch' &&
      _original?.nutrients.energy == 680 &&
      !_foodChanged &&
      _foods.length == 3 &&
      _foods.any((f) => f.id == 'fish' && f.grams.text == '150');

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_type == null) {
      showDemoMessage(context, '请选择餐别');
      return;
    }
    setState(() => _saving = true);
    double? amount(String code) =>
        double.tryParse(_nutrients[code]!.text.trim());
    final nutrients = Nutrients(
      energy: amount('energy'),
      protein: amount('protein'),
      carbs: amount('carbs'),
      fat: amount('fat'),
      fiber: amount('fiber'),
      sodium: amount('sodium'),
    );
    final id =
        widget.mealId ?? 'manual-${DateTime.now().microsecondsSinceEpoch}';
    final meal = MealEntry(
      id: id,
      title: _title.text.trim(),
      type: _type!,
      consumedAt: _date,
      nutrients: nutrients,
      status: AnalysisStatus.ready,
      source: RecordSource.manual,
      notes: _notes.text.trim(),
      confirmed: _original?.confirmed ?? true,
      foods: _foods.map((f) {
        Nutrients foodNutrients = const Nutrients();
        if (!_foodChanged) {
          for (final existing in _original?.foods ?? <FoodPortion>[]) {
            if (existing.id == f.id) foodNutrients = existing.nutrients;
          }
        } else if (_sampleApplied) {
          foodNutrients = Nutrients(
            energy: f.id == 'fish'
                ? 240
                : f.id == 'rice'
                ? 260
                : 120,
          );
        }
        return FoodPortion(
          id: f.id,
          name: f.name.text.trim(),
          grams: double.tryParse(f.grams.text) ?? 0,
          nutrients: foodNutrients,
        );
      }).toList(),
    );
    ref.read(demoProvider.notifier).saveMeal(meal);
    setState(() {
      _dirty = false;
      _leaving = true;
    });
    showDemoMessage(context, '已保存到内存演示，关联统计已更新；重启后重置');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isNew) {
        context.pushReplacement(AppRoutes.mealDetail(id));
      } else {
        context.pop();
      }
    });
  }

  Widget _foodCard(_FoodDraft food) {
    FoodPortion? original;
    for (final existing in _original?.foods ?? <FoodPortion>[]) {
      if (existing.id == food.id) original = existing;
    }
    final showOriginal = original != null && food.id == 'fish';
    final amount = TextFormField(
      controller: food.grams,
      decoration: InputDecoration(
        labelText: showOriginal ? '修正后重量' : '实际食用量',
        suffixText: 'g',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return '请填写实际食用量';
        return _number(value);
      },
      onChanged: (_) => _invalidateNutrition(),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: food.name,
                  decoration: const InputDecoration(
                    hintText: '菜品名称',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请填写菜品名称' : null,
                  onChanged: (_) => _invalidateNutrition(),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.red),
                onPressed: () {
                  setState(() => _foods.remove(food));
                  food.dispose();
                  _invalidateNutrition();
                },
                child: const Text('移除'),
              ),
            ],
          ),
          if (showOriginal) ...[
            const Text(
              '重量基准：熟重 / 实际食用量',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '原估算重量',
                      suffixText: 'g',
                    ),
                    child: Text(
                      formatAmount(original.grams),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(child: amount),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            amount,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isNew && _original == null) {
      return const AppPage(
        title: '修正本餐',
        showBack: true,
        children: [InfoBanner(text: '记录不存在，无法编辑。请返回饮食历史。')],
      );
    }
    final energy = double.tryParse(_nutrients['energy']!.text);
    final originalEnergy = _original?.nutrients.energy;
    final todayEnergy = ref.watch(demoProvider).todayTotal.energy;
    final afterToday =
        sameDay(_date, demoDate) &&
            _original != null &&
            sameDay(_original!.consumedAt, demoDate) &&
            energy != null &&
            originalEnergy != null &&
            todayEnergy != null
        ? todayEnergy - originalEnergy + energy
        : null;
    return PopScope(
      canPop: !_dirty || _leaving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_leaving) _confirmLeave();
      },
      child: Form(
        key: _form,
        child: AppPage(
          title: _isNew ? '手工记录' : '修正${_original!.type.label}',
          showBack: true,
          footer: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '保存后同步更新单餐、当日与趋势',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: _saving
                    ? '正在保存演示…'
                    : _isNew
                    ? '保存记录（演示）'
                    : '保存修正（演示）',
                icon: AppIcons.check,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
          children: [
            AdaptiveColumns(
              main: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isNew) ...[
                        TextFormField(
                          controller: _title,
                          decoration: const InputDecoration(
                            labelText: '餐食名称',
                            hintText: '填写这餐吃了什么',
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? '请填写餐食名称' : null,
                          onChanged: (_) => _markDirty(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final type = DropdownButtonFormField<MealType>(
                            initialValue: _type,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: '餐别'),
                            hint: const Text('请选择'),
                            items: MealType.values
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (type) => setState(() {
                              _type = type;
                              _dirty = true;
                            }),
                          );
                          final time = Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                '用餐时间',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: _changeDate,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                child: Text(
                                  '${_date.month}月${_date.day}日 ${mealTime(_date)}',
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          );
                          final scale =
                              MediaQuery.textScalerOf(context).scale(14) / 14;
                          if (constraints.maxWidth < 300 * scale) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                type,
                                const SizedBox(height: 16),
                                time,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 4, child: type),
                              const SizedBox(width: 16),
                              Expanded(flex: 5, child: time),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (!_isNew)
                  AppCard(
                    color: AppColors.greenSoft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeading(title: '本餐更新预览'),
                        const SizedBox(height: 12),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 14,
                          runSpacing: 8,
                          children: [
                            Text(
                              formatAmount(originalEnergy),
                              style: const TextStyle(
                                fontSize: 28,
                                color: AppColors.muted,
                              ),
                            ),
                            const Icon(
                              AppIcons.chevronRight,
                              size: 22,
                              color: AppColors.muted,
                            ),
                            Text(
                              formatAmount(energy),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (energy != null)
                              const Text(
                                'kcal',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 14,
                                ),
                              ),
                            if (energy != null &&
                                originalEnergy != null &&
                                energy != originalEnergy)
                              AppBadge(
                                label:
                                    '${energy < originalEnergy ? '减少' : '增加'}${formatAmount((energy - originalEnergy).abs())}',
                              ),
                          ],
                        ),
                        if (afterToday != null)
                          Text('保存后今日已记录能量：${formatAmount(afterToday)} kcal'),
                        const SizedBox(height: 8),
                        const Text(
                          '保存前不更新单餐、当日和趋势。',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                const SectionHeading(title: '按实际食用量核对'),
                if (_canSample)
                  AppButton(
                    label: '应用样例：煎鱼 150 g → 120 g',
                    secondary: true,
                    onPressed: _applySample,
                  ),
                ..._foods.map((food) => _foodCard(food)),
                AppButton(
                  label: '添加漏识别的菜品',
                  secondary: true,
                  icon: AppIcons.plus,
                  onPressed: () {
                    setState(
                      () => _foods.add(
                        _FoodDraft(
                          'food-${DateTime.now().microsecondsSinceEpoch}',
                          '',
                          '',
                        ),
                      ),
                    );
                    _invalidateNutrition();
                  },
                ),
                if (_foodChanged && !_sampleApplied)
                  const InfoBanner(text: '菜品或重量已改变。没有可靠换算依据，营养已留空，请按当前整份手动核对。'),
              ],
              aside: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeading(title: '营养核对', detail: '当前整份营养'),
                      const SizedBox(height: 8),
                      const Text(
                        '未填值保持未知，不自动转成零',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      ...[
                        ('energy', '能量', 'kcal'),
                        ('protein', '蛋白质', 'g'),
                        ('carbs', '碳水', 'g'),
                        ('fat', '脂肪', 'g'),
                        if (_extraNutrients) ...[
                          ('fiber', '膳食纤维', 'g'),
                          ('sodium', '钠', 'mg'),
                        ],
                      ].map(
                        (field) => Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: TextFormField(
                            controller: _nutrients[field.$1],
                            decoration: InputDecoration(
                              labelText: field.$2,
                              hintText: '待补充',
                              suffixText: field.$3,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: _number,
                            onChanged: (_) => _markDirty(),
                          ),
                        ),
                      ),
                      if (!_extraNutrients)
                        TextButton(
                          onPressed: () => setState(() {
                            _extraNutrients = true;
                            _dirty = true;
                          }),
                          child: const Text('添加营养项'),
                        ),
                    ],
                  ),
                ),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_isNew) ...[
                        TextFormField(
                          controller: _title,
                          decoration: const InputDecoration(labelText: '餐食名称'),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? '请填写餐食名称' : null,
                          onChanged: (_) => _markDirty(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _notes,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '补充备注',
                          hintText: '补充实际份量、烹饪方式或菜品说明',
                        ),
                        onChanged: (_) => _markDirty(),
                      ),
                    ],
                  ),
                ),
                const InfoBanner(
                  text: '保存前确认\n仅预览调整，保存后才更新统计。实际份量只换算一次。跨日期修改后，原日期与新日期的统计都会更新。当前仅保存内存演示，不代表真实提交。',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
