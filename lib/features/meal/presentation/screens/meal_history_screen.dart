import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/demo/demo_store.dart';
import 'package:diet_client/core/presentation/app_routes.dart';

import '../widgets/meal_widgets.dart';

class MealHistoryScreen extends ConsumerStatefulWidget {
  const MealHistoryScreen({super.key});
  @override
  ConsumerState<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends ConsumerState<MealHistoryScreen> {
  DateTime _from = demoDate.subtract(const Duration(days: 6));
  DateTime _to = demoDate;
  DateTime _appliedFrom = demoDate.subtract(const Duration(days: 6));
  DateTime _appliedTo = demoDate;
  MealType? _type;
  MealType? _appliedType;
  final _query = TextEditingController();
  String _appliedQuery = '';
  int _limit = 6;
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
    final meals =
        ref
            .watch(demoProvider)
            .meals
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
    return AppPage(
      title: '饮食历史',
      showBack: true,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pick(true),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('开始日期  ${mealDate(_from)}'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _pick(false),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('结束日期  ${mealDate(_to)}'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _query,
                decoration: const InputDecoration(
                  hintText: '搜索备注或菜品名称',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text('全部'),
                    selected: _type == null,
                    onSelected: (_) => setState(() => _type = null),
                  ),
                  ...MealType.values.map(
                    (type) => ChoiceChip(
                      label: Text(type.label),
                      selected: _type == type,
                      onSelected: (_) => setState(() => _type = type),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  AppButton(label: '重置', secondary: true, onPressed: _reset),
                  AppButton(label: '应用筛选', onPressed: _apply),
                ],
              ),
            ],
          ),
        ),
        Text(
          '${mealDate(_appliedFrom)} - ${mealDate(_appliedTo)} / ${_appliedType?.label ?? '全部餐别'}',
          style: const TextStyle(color: AppColors.muted),
        ),
        SectionHeading(title: '共 ${meals.length} 条记录'),
        if (meals.isEmpty)
          AppCard(
            child: Column(
              children: [
                const Text('没有符合这些条件的记录'),
                const SizedBox(height: 12),
                AppButton(label: '重置筛选', secondary: true, onPressed: _reset),
              ],
            ),
          ),
        for (var i = 0; i < visible.length; i++) ...[
          if (i == 0 ||
              !sameDay(visible[i].consumedAt, visible[i - 1].consumedAt))
            SectionHeading(
              title:
                  '${visible[i].consumedAt.month}月${visible[i].consumedAt.day}日${sameDay(visible[i].consumedAt, demoDate) ? '，今天' : ''}',
            ),
          MealRow(
            meal: visible[i],
            onTap: () => context.push(AppRoutes.mealDetail(visible[i].id)),
          ),
        ],
        if (_limit < meals.length)
          AppButton(
            label: '加载更早记录',
            secondary: true,
            onPressed: () => setState(() => _limit += 6),
          ),
      ],
    );
  }
}
