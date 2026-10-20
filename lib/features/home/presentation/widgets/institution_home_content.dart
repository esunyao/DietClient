import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/app_routes.dart';
import '../../../../demo/demo_store.dart';
import 'home_summary.dart';
import 'seven_day_summary.dart';

class InstitutionHomeContent extends StatelessWidget {
  const InstitutionHomeContent({super.key, required this.data});
  final DemoSnapshot data;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= AppLayout.columnsMinWidth;
      final main = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeNutritionSummary(data: data, wide: wide),
          if (!wide) const SizedBox(height: 12),
          HomeMeals(meals: data.todayMeals, wide: wide),
          const SizedBox(height: 22),
          SevenDaySummary(points: data.trend(7)),
        ],
      );
      final aside = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InstitutionDinner(data: data),
          const SizedBox(height: 24),
          _WeeklyReport(data: data),
          const SizedBox(height: 24),
          const _PrivacyNotice(),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: AppLayout.mainColumnWidth.toInt(), child: main),
                const SizedBox(width: AppLayout.columnGap),
                Expanded(
                  flex: AppLayout.asideColumnWidth.toInt(),
                  child: aside,
                ),
              ],
            )
          else ...[
            main,
            const SizedBox(height: 24),
            aside,
          ],
          const SizedBox(height: 48),
          const Text(
            '更完整地理解这些记录',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          const AppCard(
            radius: 16,
            padding: EdgeInsets.all(24),
            child: Text(
              '已记录合计只包含已确认且有数值的分析结果，不从未记录时段推断是否进食或全天营养缺口。\n\n如实际份量与估算不同，保存修正后，单餐、今日合计与趋势会同步更新。',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '需要补充时',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.capture),
                icon: Icon(AppIcons.camera, size: 22),
                label: const Text('拍照记录'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.manualMeal),
                icon: Icon(AppIcons.edit, size: 22),
                label: const Text('手工补录'),
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.healthRecords),
                child: const Text('管理健康档案'),
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.institutionMenu),
                child: const Text('食堂菜单'),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _InstitutionDinner extends StatelessWidget {
  const _InstitutionDinner({required this.data});
  final DemoSnapshot data;

  @override
  Widget build(BuildContext context) {
    final confirmed = data.institutionConfirmed;
    final dinner = data.meal('institution-dinner');
    final plan = demoPlans.firstWhere((plan) => plan.id == 'fish');
    return AppCard(
      radius: 16,
      color: AppColors.greenSoft,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  '机构晚餐',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: AppBadge(
                  label: confirmed ? '已本人确认' : '待本人确认',
                  color: confirmed ? AppColors.green : AppColors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '医疗院 · 一号食堂',
            style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.2),
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              text: homeAmount(
                confirmed ? dinner?.nutrients.energy : plan.energy,
              ),
              children: [
                TextSpan(
                  text: confirmed ? ' kcal / 已确认食用量' : ' kcal / 标准份量',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            plan.foods.map((food) => food.name).join('、'),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 46),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => context.push(AppRoutes.institutionSync),
            icon: Icon(AppIcons.checkCircle, size: 22),
            label: Text(confirmed ? '查看确认结果' : '核对机构餐食'),
          ),
          const SizedBox(height: 6),
          Text(
            confirmed ? '已按本人核对的实际用餐量计入记录' : '确认实际用餐前，不计入摄入',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyReport extends StatelessWidget {
  const _WeeklyReport({required this.data});
  final DemoSnapshot data;

  @override
  Widget build(BuildContext context) {
    final points = data.trend(7);
    final days = points.where((point) => point.nutrients.energy != null).length;
    final analyzing = points.fold(
      0,
      (sum, point) => sum + point.analyzingCount,
    );
    final report = data.reports.isEmpty ? null : data.reports.first;
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.reports, color: AppColors.primary, size: 27),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  report?.title ?? '本周营养记录报告',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            report?.period ?? '暂无报告预览',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '$days个有数值记录日${analyzing > 0 ? '，仍有$analyzing餐分析中' : ''}',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          AppBadge(
            label: report?.stale == true ? '记录变化，待更新' : '参考报告',
            color: report?.stale == true ? AppColors.amber : AppColors.green,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push(AppRoutes.reports),
              child: const Text('查看报告', style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNotice extends ConsumerWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppCard(
    radius: 16,
    padding: EdgeInsets.zero,
    child: Semantics(
      label: '暂时隐藏个人信息',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => ref.read(demoProvider.notifier).setPrivacyHidden(true),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(AppIcons.shieldCheck, color: AppColors.primary, size: 26),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '仅展示你的个人数据',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '机构身份不等于健康资料共享',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
