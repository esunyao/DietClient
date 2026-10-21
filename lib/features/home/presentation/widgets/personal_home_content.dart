import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/app_routes.dart';
import '../../../../demo/demo_store.dart';
import 'home_summary.dart';
import 'personal_nutrition_summary.dart';

class PersonalHomeContent extends StatelessWidget {
  const PersonalHomeContent({
    super.key,
    required this.data,
    this.narrowPage = false,
  });
  final DemoSnapshot data;
  final bool narrowPage;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= AppLayout.columnsMinWidth;
      final main = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HomeRecordEntry(),
          const SizedBox(height: 20),
          const HomeQuickActions(),
          const SizedBox(height: 20),
          PersonalNutritionSummary(data: data),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: narrowPage ? 4 : 0),
            child: HomeMeals(meals: data.todayMeals),
          ),
          if (!wide) ...[const SizedBox(height: 20), _LunchCheck(data: data)],
        ],
      );
      if (!wide) return main;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: AppLayout.mainColumnWidth.toInt(), child: main),
          const SizedBox(width: AppLayout.columnGap),
          Expanded(
            flex: AppLayout.asideColumnWidth.toInt(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LunchCheck(data: data),
                const SizedBox(height: 24),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            AppIcons.reports,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              '本周营养报告',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '汇总已有记录，保留缺失日期',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.reports),
                        child: const Text('查看报告'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class HomeRecordEntry extends StatelessWidget {
  const HomeRecordEntry({super.key});

  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.primary,
    radius: 24,
    padding: const EdgeInsets.fromLTRB(20, 8, 8, 10),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(13) > 17;
        final plateSize = compact ? 82.0 : 126.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '拍照记一餐',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '智能识别食物，轻松记录热量',
                    style: TextStyle(
                      color: Color(0xFFD9E9DF),
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 7),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.greenSoft,
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(145, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => context.push(AppRoutes.capture),
                    icon: Icon(AppIcons.camera, size: 20),
                    label: const Text('拍照记录'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ExcludeSemantics(
              child: Image.asset(
                'assets/images/home_capture_bowl.png',
                width: plateSize,
                height: plateSize,
                cacheWidth: 384,
                fit: BoxFit.contain,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: _QuickAction(
          label: '手工记录',
          icon: AppIcons.edit,
          route: AppRoutes.manualMeal,
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: _QuickAction(
          label: '历史记录',
          icon: AppIcons.history,
          route: AppRoutes.mealHistory,
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: _QuickAction(
          label: '健康档案',
          icon: AppIcons.healthRecord,
          route: AppRoutes.healthRecords,
        ),
      ),
    ],
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.route,
  });
  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 100 ||
                MediaQuery.textScalerOf(context).scale(14) > 20;
            final iconWidget = Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.greenSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            );
            final text = Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            );
            if (compact) {
              return Column(
                children: [iconWidget, const SizedBox(height: 6), text],
              );
            }
            return Row(
              children: [
                iconWidget,
                const SizedBox(width: 4),
                Expanded(child: text),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.muted,
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _LunchCheck extends StatelessWidget {
  const _LunchCheck({required this.data});
  final DemoSnapshot data;

  @override
  Widget build(BuildContext context) {
    final lunch = data.meal('lunch');
    return AppCard(
      color: AppColors.greenSoft,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(
          lunch == null
              ? AppRoutes.mealHistory
              : AppRoutes.mealDetail(lunch.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.checkCircle, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lunch == null ? '查看已有餐食' : '核对午餐份量',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      '照片估算可修正，保存后统计同步更新',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(AppIcons.chevronRight, color: AppColors.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
