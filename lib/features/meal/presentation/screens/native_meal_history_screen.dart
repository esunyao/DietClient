import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';

import '../../../../core/presentation/app_routes.dart';
import '../../../../core/nutrition/application/nutrition_providers.dart';
import '../../../../core/nutrition/application/analysis_polling.dart';
import '../widgets/native_meal_widgets.dart';

class NativeMealHistoryScreen extends ConsumerStatefulWidget {
  const NativeMealHistoryScreen({super.key});
  @override
  ConsumerState<NativeMealHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends ConsumerState<NativeMealHistoryScreen> {
  late DateTime _from = DateUtils.dateOnly(DateTime.now())
      .subtract(const Duration(days: 6));
  late DateTime _to = DateUtils.dateOnly(DateTime.now());
  late String _dateFrom = nutritionDate(_from), _dateTo = nutritionDate(_to);
  String? _type, _appliedType;
  String _keyword = '';
  int _page = 1;
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _apply() {
    if (_from.isAfter(_to)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('结束日期不能早于开始日期')));
      return;
    }
    setState(() {
      _dateFrom = nutritionDate(_from);
      _dateTo = nutritionDate(_to);
      _appliedType = _type;
      _keyword = _search.text.trim();
      _page = 1;
    });
  }

  Future<void> _pick(bool from) async {
    final value = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (value != null && mounted) {
      setState(() {
        if (from) {
          _from = value;
        } else {
          _to = value;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = (
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      mealType: _appliedType,
      keyword: _keyword.isEmpty ? null : _keyword,
      page: _page,
      pageSize: 20,
    );
    final result = ref.watch(mealsProvider(query));
    final page = result.value;
    return AppPage(
      demoLabel: null,
      title: '饮食历史',
      showBack: true,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: () => _pick(true),
                    child: Text('开始 ${nutritionDate(_from)}'),
                  ),
                  TextButton(
                    onPressed: () => _pick(false),
                    child: Text('结束 ${nutritionDate(_to)}'),
                  ),
                ],
              ),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  labelText: '搜索备注或菜品名称',
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (_) => _apply(),
              ),
              const SizedBox(height: 12),
              AppSegmented(
                labels: ['全部', ...mealTypes.values],
                selected: _type == null
                    ? 0
                    : mealTypes.keys.toList().indexOf(_type!) + 1,
                onChanged: (index) => setState(
                  () => _type = index == 0
                      ? null
                      : mealTypes.keys.elementAt(index - 1),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        _from = DateUtils.dateOnly(DateTime.now())
                            .subtract(const Duration(days: 6));
                        _to = DateUtils.dateOnly(DateTime.now());
                        _type = null;
                        _search.clear();
                        _apply();
                      },
                      child: const Text('重置'),
                    ),
                  ),
                  Expanded(
                    child: AppButton(label: '应用筛选', onPressed: _apply),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (result.isLoading && page == null)
          const Center(child: CircularProgressIndicator()),
        if (result.hasError)
          NutritionError(
            error: result.error!,
            retry: () => ref.invalidate(mealsProvider(query)),
          ),
        if (page != null)
          NutritionPolling(
            refreshKey: query,
            onRefresh: () => ref.invalidate(mealsProvider(query)),
            pending: page.items.any((m) => analysisPending(m.analysisStatus)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('共 ${page.total} 条记录 · 第 ${page.page} 页'),
                if (page.items.isEmpty)
                  const AppCard(child: Text('没有符合这些条件的记录')),
                for (final meal in page.items)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: NativeMealTile(
                      meal: meal,
                      onTap: () =>
                          context.push(AppRoutes.mealDetail(meal.mealId)),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _page > 1
                          ? () => setState(() => _page--)
                          : null,
                      child: const Text('上一页'),
                    ),
                    TextButton(
                      onPressed: _page * page.pageSize < page.total
                          ? () => setState(() => _page++)
                          : null,
                      child: const Text('下一页'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
