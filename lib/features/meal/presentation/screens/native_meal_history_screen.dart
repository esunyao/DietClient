import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/nutrition/application/analysis_polling.dart';
import '../../../../core/nutrition/application/nutrition_providers.dart';
import '../../../../core/presentation/navigation_manager.dart';
import '../../../../core/presentation/ui_preferences.dart';
import '../widgets/native_meal_widgets.dart';

/// 原生真实餐食历史列表页，支持服务端筛选分页及紧凑/照片卡片双视图切换。
class NativeMealHistoryScreen extends ConsumerStatefulWidget {
  const NativeMealHistoryScreen({super.key});

  @override
  ConsumerState<NativeMealHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends ConsumerState<NativeMealHistoryScreen> {
  late DateTime _from = DateUtils.dateOnly(DateTime.now())
      .subtract(const Duration(days: 6));
  late DateTime _to = DateUtils.dateOnly(DateTime.now());
  late String _dateFrom = formatIsoDate(_from);
  late String _dateTo = formatIsoDate(_to);
  String? _type;
  String? _appliedType;
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
      _dateFrom = formatIsoDate(_from);
      _dateTo = formatIsoDate(_to);
      _appliedType = _type;
      _keyword = _search.text.trim();
      _page = 1;
    });
  }

  void _resetFilters() {
    _from = DateUtils.dateOnly(DateTime.now())
        .subtract(const Duration(days: 6));
    _to = DateUtils.dateOnly(DateTime.now());
    _type = null;
    _search.clear();
    _apply();
  }

  Future<void> _pick(bool from) async {
    final value = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (from) {
        _from = value;
      } else {
        _to = value;
      }
    });
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
    final layout = ref.watch(
      uiPreferencesProvider.select((p) => p.mealHistoryLayout),
    );
    final nutrition = ref.read(nutritionManagerProvider);
    final navigation = ref.read(navigationManagerProvider);

    return NutritionPolling(
      expandChild: true,
      refreshKey: query,
      pending:
          page?.items.any((m) => analysisPending(m.analysisStatus)) ?? false,
      onRefresh: () => nutrition.refreshMealsIfIdle(query),
      child: AppPage(
        demoLabel: null,
        title: '饮食历史',
        showBack: true,
        children: [
          _HistoryFilterCard(
            from: _from,
            to: _to,
            selectedType: _type,
            searchController: _search,
            onPickFrom: () => _pick(true),
            onPickTo: () => _pick(false),
            onTypeChanged: (index) => setState(
              () => _type = index == 0 ? null : kMealTypeKeys[index - 1],
            ),
            onReset: _resetFilters,
            onApply: _apply,
          ),
          if (result.isLoading && page == null)
            const Center(child: CircularProgressIndicator()),
          if (result.hasError)
            NutritionError(
              error: result.error!,
              retry: () => nutrition.refreshMeals(query),
            ),
          if (page != null) ...[
            Text('共 ${page.total} 条记录 · 第 ${page.page} 页'),
            if (page.items.isEmpty) const AppCard(child: Text('没有符合这些条件的记录')),
            for (final meal in page.items)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: NativeMealTile(
                  key: ValueKey(meal.mealId),
                  meal: meal,
                  layout: layout,
                  onPhotoTap: (imageId) => navigation.openMealPhotos(
                    context,
                    meal.mealId,
                    imageId: imageId,
                  ),
                  onTap: () => navigation.openMealDetail(context, meal.mealId),
                ),
              ),
            _HistoryPaginationBar(
              pageIndex: _page,
              pageSize: page.pageSize,
              total: page.total,
              onPrevious: () => setState(() => _page--),
              onNext: () => setState(() => _page++),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryFilterCard extends StatelessWidget {
  const _HistoryFilterCard({
    required this.from,
    required this.to,
    required this.selectedType,
    required this.searchController,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onTypeChanged,
    required this.onReset,
    required this.onApply,
  });

  final DateTime from;
  final DateTime to;
  final String? selectedType;
  final TextEditingController searchController;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final ValueChanged<int> onTypeChanged;
  final VoidCallback onReset;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          children: [
            TextButton(
              onPressed: onPickFrom,
              child: Text('开始 ${formatIsoDate(from)}'),
            ),
            TextButton(
              onPressed: onPickTo,
              child: Text('结束 ${formatIsoDate(to)}'),
            ),
          ],
        ),
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            labelText: '搜索备注或菜品名称',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (_) => onApply(),
        ),
        const SizedBox(height: 12),
        AppSegmented(
          labels: ['全部', ...kMealTypeDisplayLabels],
          selected: selectedType == null
              ? 0
              : kMealTypeKeys.indexOf(selectedType!) + 1,
          onChanged: onTypeChanged,
        ),
        Row(
          children: [
            Expanded(
              child: TextButton(onPressed: onReset, child: const Text('重置')),
            ),
            Expanded(
              child: AppButton(label: '应用筛选', onPressed: onApply),
            ),
          ],
        ),
      ],
    ),
  );
}

class _HistoryPaginationBar extends StatelessWidget {
  const _HistoryPaginationBar({
    required this.pageIndex,
    required this.pageSize,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int pageIndex;
  final int pageSize;
  final int total;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      TextButton(
        onPressed: pageIndex > 1 ? onPrevious : null,
        child: const Text('上一页'),
      ),
      TextButton(
        onPressed: pageIndex * pageSize < total ? onNext : null,
        child: const Text('下一页'),
      ),
    ],
  );
}
