import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/demo/demo_store.dart';
import 'package:diet_client/core/presentation/app_routes.dart';

import '../widgets/meal_widgets.dart';
import '../../../../core/config/ui_preview_config.dart';
import 'native_meal_history_screen.dart';

class MealHistoryScreen extends ConsumerWidget {
  const MealHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(nativeNutritionEnabledProvider)
      ? const NativeMealHistoryScreen()
      : const _DemoMealHistoryScreen();
}

class _DemoMealHistoryScreen extends ConsumerStatefulWidget {
  const _DemoMealHistoryScreen();
  @override
  ConsumerState<_DemoMealHistoryScreen> createState() =>
      _MealHistoryScreenState();
}

class _MealHistoryScreenState extends ConsumerState<_DemoMealHistoryScreen> {
  DateTime _from = demoDate.subtract(const Duration(days: 6));
  DateTime _to = demoDate;
  DateTime _appliedFrom = demoDate.subtract(const Duration(days: 6));
  DateTime _appliedTo = demoDate;
  MealType? _type;
  MealType? _appliedType;
  final _query = TextEditingController();
  String _appliedQuery = '';
  int _limit = 6;
  String? _selectedMealId = 'lunch';
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _pick(bool from) async {
    final date = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date != null && mounted) {
      setState(() {
        if (from) {
          _from = date;
        } else {
          _to = date;
        }
      });
    }
  }

  void _apply() {
    if (_from.isAfter(_to)) {
      showDemoMessage(context, '结束日期不能早于开始日期');
      return;
    }
    setState(() {
      _appliedFrom = _from;
      _appliedTo = _to;
      _appliedType = _type;
      _appliedQuery = _query.text.trim();
      _limit = 6;
    });
  }

  void _reset() {
    setState(() {
      _from = demoDate.subtract(const Duration(days: 6));
      _to = demoDate;
      _type = null;
      _query.clear();
    });
    _apply();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(demoProvider);
    final meals =
        state.meals
            .where(
              (m) =>
                  !DateUtils.dateOnly(m.consumedAt).isBefore(_appliedFrom) &&
                  !DateUtils.dateOnly(m.consumedAt).isAfter(_appliedTo) &&
                  (_appliedType == null || m.type == _appliedType) &&
                  '${m.title} ${m.notes} ${m.foods.map((f) => f.name).join(' ')}'
                      .contains(_appliedQuery),
            )
            .toList()
          ..sort((a, b) => b.consumedAt.compareTo(a.consumedAt));
    final visible = meals.take(_limit).toList();
    MealEntry? selected;
    for (final meal in visible) {
      if (meal.id == _selectedMealId) selected = meal;
    }
    selected ??= visible.isEmpty ? null : visible.first;
    return AppPage(
      demoLabel: '设计样例 · 演示数据',
      title: '饮食历史',
      showBack: true,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= AppLayout.columnsMinWidth;
            final selectedMeal = selected;
            final groups = <List<MealEntry>>[];
            for (final meal in visible) {
              if (groups.isEmpty ||
                  !sameDay(groups.last.first.consumedAt, meal.consumedAt)) {
                groups.add([]);
              }
              groups.last.add(meal);
            }
            for (final group in groups) {
              group.sort((a, b) => a.consumedAt.compareTo(b.consumedAt));
            }
            return AdaptiveColumns(
              main: [
                _filters(wide),
                if (!wide)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_appliedFrom.month}月${_appliedFrom.day}日 - ${_appliedTo.month}月${_appliedTo.day}日 / ${_appliedType?.label ?? '全部餐别'}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '共 ${meals.length} 条记录',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                if (meals.isEmpty)
                  AppCard(
                    child: Column(
                      children: [
                        const Text('没有符合这些条件的记录'),
                        const SizedBox(height: 12),
                        AppButton(
                          label: '重置筛选',
                          secondary: true,
                          onPressed: _reset,
                        ),
                      ],
                    ),
                  ),
                for (
                  var groupIndex = 0;
                  groupIndex < groups.length;
                  groupIndex++
                ) ...[
                  SectionHeading(
                    title:
                        '${groups[groupIndex].first.consumedAt.month}月${groups[groupIndex].first.consumedAt.day}日${sameDay(groups[groupIndex].first.consumedAt, demoDate) ? '，今天' : ''}',
                    detail: wide && groupIndex == 0
                        ? '共 ${meals.length} 条记录'
                        : null,
                  ),
                  if (wide)
                    AppCard(
                      radius: 16,
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          for (
                            var i = 0;
                            i < groups[groupIndex].length;
                            i++
                          ) ...[
                            MealRow(
                              meal: groups[groupIndex][i],
                              embedded: true,
                              selected:
                                  groups[groupIndex][i].id == selectedMeal?.id,
                              onTap: () => setState(
                                () =>
                                    _selectedMealId = groups[groupIndex][i].id,
                              ),
                            ),
                            if (i < groups[groupIndex].length - 1)
                              const Divider(
                                height: 1,
                                indent: 80,
                                endIndent: 14,
                              ),
                          ],
                        ],
                      ),
                    )
                  else
                    for (final meal in groups[groupIndex])
                      MealRow(
                        meal: meal,
                        onTap: () =>
                            context.push(AppRoutes.mealDetail(meal.id)),
                      ),
                ],
                if (_limit < meals.length)
                  AppButton(
                    label: '加载更早记录',
                    secondary: true,
                    onPressed: () => setState(() => _limit += 6),
                  ),
              ],
              aside: wide
                  ? [
                      if (selectedMeal != null) ...[
                        AppCard(
                          radius: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                '选中记录',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '${selectedMeal.consumedAt.month}月${selectedMeal.consumedAt.day}日 · ${selectedMeal.type.label}',
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${mealTime(selectedMeal.consumedAt)} / ${selectedMeal.source.label}',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 20),
                              MealNutrients(
                                nutrients:
                                    selectedMeal.status == AnalysisStatus.ready
                                    ? selectedMeal.nutrients
                                    : const Nutrients(),
                                title:
                                    selectedMeal.status == AnalysisStatus.ready
                                    ? null
                                    : selectedMeal.status.label,
                                showScore: false,
                                embedded: true,
                                leading: const PlateIllustration(size: 80),
                              ),
                              const SizedBox(height: 16),
                              AppButton(
                                label: '查看单餐详情',
                                secondary: true,
                                onPressed: () => context.push(
                                  AppRoutes.mealDetail(selectedMeal.id),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (!state.institutionConfirmed)
                        const InfoBanner(
                          icon: AppIcons.sync,
                          text: '机构餐食尚未入账\n另有 1 条机构晚餐待本人确认，不出现在已确认摄入合计中。',
                        ),
                    ]
                  : const [],
            );
          },
        ),
      ],
    );
  }

  Widget _dateField(String label, DateTime date, VoidCallback onTap) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                mealDate(date),
                style: const TextStyle(color: AppColors.ink, fontSize: 14),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(AppIcons.calendar, color: AppColors.muted, size: 18),
          ],
        ),
      ),
    ],
  );

  Widget _filters(bool wide) {
    final dates = LayoutBuilder(
      builder: (context, constraints) {
        final minimum = 300 * MediaQuery.textScalerOf(context).scale(14) / 14;
        if (constraints.maxWidth < minimum) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dateField('开始日期', _from, () => _pick(true)),
              const SizedBox(height: 12),
              _dateField('结束日期', _to, () => _pick(false)),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: _dateField('开始日期', _from, () => _pick(true))),
            const SizedBox(width: 14),
            Expanded(child: _dateField('结束日期', _to, () => _pick(false))),
          ],
        );
      },
    );
    final search = TextField(
      controller: _query,
      decoration: InputDecoration(
        hintText: '搜索备注或菜品名称',
        prefixIcon: const Icon(AppIcons.search),
        fillColor: AppColors.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
      ),
      onSubmitted: (_) => _apply(),
    );
    final types = AppSegmented(
      labels: ['全部', ...MealType.values.map((type) => type.label)],
      selected: _type == null ? 0 : MealType.values.indexOf(_type!) + 1,
      equalWidth: true,
      onChanged: (index) => setState(
        () => _type = index == 0 ? null : MealType.values[index - 1],
      ),
    );
    final actions = Row(
      children: [
        Expanded(
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.greenSoft,
              foregroundColor: AppColors.primary,
            ),
            onPressed: _reset,
            child: const Text('重置'),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: wide ? 1 : 2,
          child: AppButton(label: wide ? '筛选' : '应用筛选', onPressed: _apply),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 6, child: dates),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '关键词',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    search,
                  ],
                ),
              ),
            ],
          )
        else ...[
          dates,
          const SizedBox(height: 20),
          search,
        ],
        const SizedBox(height: 16),
        if (wide)
          Row(
            children: [
              Expanded(flex: 5, child: types),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: actions),
            ],
          )
        else ...[
          types,
          const SizedBox(height: 14),
          actions,
        ],
        const SizedBox(height: 6),
      ],
    );
  }
}
