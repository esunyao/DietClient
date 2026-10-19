import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/core/presentation/app_routes.dart';
import 'package:diet_client/demo/demo_store.dart';

class TrendsScreen extends ConsumerStatefulWidget {
  const TrendsScreen({super.key});
  @override
  ConsumerState<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends ConsumerState<TrendsScreen> {
  int _range = 0;
  int _nutrient = 0;
  static const _nutrients = [
    (code: 'energy', label: '能量', unit: 'kcal'),
    (code: 'protein', label: '蛋白质', unit: 'g'),
    (code: 'carbs', label: '碳水', unit: 'g'),
    (code: 'fat', label: '脂肪', unit: 'g'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(demoProvider);
    final days = [7, 30, 90][_range];
    final points = state.trend(days);
    final nutrient = _nutrients[_nutrient];
    final values = points.map((p) => p.nutrients.value(nutrient.code)).toList();
    final known = values.whereType<double>().toList();
    final average = known.isEmpty
        ? null
        : known.reduce((a, b) => a + b) / known.length;
    final records = points.fold(0, (sum, point) => sum + point.recordCount);
    final analyzing = points.fold(
      0,
      (sum, point) => sum + point.analyzingCount,
    );
    final labels = points.map((p) => '${p.date.month}/${p.date.day}').toList();
    return AppPage(
      title: '营养趋势',
      subtitle: '看记录中的变化',
      children: [
        AppSegmented(
          labels: const ['7 日', '30 日', '90 日'],
          selected: _range,
          onChanged: (value) => setState(() => _range = value),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _nutrients.length; i++)
              ChoiceChip(
                label: Text(_nutrients[i].label),
                selected: _nutrient == i,
                onSelected: (_) => setState(() => _nutrient = i),
              ),
          ],
        ),
        AdaptiveColumns(
          main: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${nutrient.label}每日变化',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${labels.first} – ${labels.last} / 2026'),
                  const SizedBox(height: 8),
                  Text(
                    '日均 ${average == null ? '待补充' : average.round()} ${nutrient.unit}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    '仅使用有数值的记录日',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 20),
                  NutritionBarChart(
                    values: values,
                    labels: labels,
                    unit: nutrient.unit,
                  ),
                ],
              ),
            ),
            const SectionHeading(title: '逐日记录概况'),
            AppCard(
              child: Column(
                children: [
                  for (final point in points)
                    AppListRow(
                      title: '${point.date.month}月${point.date.day}日',
                      subtitle: point.recordCount == 0
                          ? '没有餐食记录'
                          : '${point.recordCount - point.analyzingCount} 餐已分析${point.analyzingCount > 0 ? ' / ${point.analyzingCount} 餐分析中' : ''}',
                      trailing: Text(
                        '${formatAmount(point.nutrients.value(nutrient.code), unknown: point.recordCount == 0 ? '未记录' : '待补充')}${point.nutrients.value(nutrient.code) == null ? '' : ' ${nutrient.unit}'}',
                      ),
                    ),
                ],
              ),
            ),
          ],
          aside: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                MetricTile(label: '有数值记录天数', value: '${known.length} / $days'),
                MetricTile(label: '餐食记录', value: '$records', unit: '餐'),
              ],
            ),
            InfoBanner(
              text:
                  '当前为记录日均值\n缺失日不补零，${analyzing > 0 ? '本周期仍有 $analyzing 餐分析中。' : '仅统计已知营养。'}',
            ),
            AppCard(
              child: AppListRow(
                title: '本周营养报告',
                subtitle: '查看数据覆盖、来源与阶段摘要',
                leading: const Icon(Icons.description_outlined),
                onTap: () => context.push(AppRoutes.reports),
              ),
            ),
            const AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '怎样读这张图',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '图表汇总已知营养值，不代表每一天完整摄入。\n\n缺少该营养素的记录日不进入均值分母。身体测量与营养摄入采用不同来源和口径。',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
