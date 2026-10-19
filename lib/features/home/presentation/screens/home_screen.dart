import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/app_routes.dart';
import '../../../../demo/demo_store.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(demoProvider);
    final meals = data.todayMeals;
    final known = meals
        .where((m) => m.confirmed && m.status == AnalysisStatus.ready)
        .length;
    final institution = data.isInstitution;
    return AppPage(
      title: institution ? '我的膳食' : '好好吃饭，从记录开始',
      subtitle: institution
          ? '医疗院 · 一号食堂（演示）　10月2日 星期五'
          : '10月2日 星期五 · 今天也关照自己',
      trailing: institution
          ? IconButton(
              tooltip: '暂时隐藏个人信息',
              onPressed: () =>
                  ref.read(demoProvider.notifier).setPrivacyHidden(true),
              icon: const Icon(Icons.visibility_off_outlined),
            )
          : const AvatarIllustration(size: 48),
      children: [
        if (!institution)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '记录这一餐',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '留下餐食，慢慢看见饮食习惯',
                            style: TextStyle(
                              color: Color(0xFFE6F0E8),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PlateIllustration(size: 92),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                  ),
                  onPressed: () => context.push(AppRoutes.capture),
                  icon: Icon(AppIcons.camera),
                  label: const Text('拍照记录 · 演示'),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.manualMeal),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('也可以手工记录'),
                ),
              ],
            ),
          ),
        AdaptiveColumns(
          main: [
            if (institution)
              AppCard(
                color: AppColors.greenSoft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeading(
                      title: '机构晚餐待确认',
                      detail: '17:35 来源到达',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const PlateIllustration(size: 76),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '清蒸鱼套餐',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                data.institutionConfirmed
                                    ? '已按实际食用量计入记录'
                                    : '配方预计 520 kcal · 归属与食用量待核对',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: data.institutionConfirmed ? '查看确认结果' : '核对并确认实际摄入',
                      onPressed: () => context.push(AppRoutes.institutionSync),
                    ),
                    if (!data.institutionConfirmed)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          '未确认的来源记录不计入已知摄入。',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(title: '今日已记录', detail: '10月2日'),
                  const SizedBox(height: 12),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 6,
                    children: [
                      Text(
                        formatAmount(data.todayTotal.energy, unknown: '—'),
                        style: const TextStyle(
                          fontSize: 39,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          'kcal',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$known餐有已知营养 · ${meals.where((m) => m.status == AnalysisStatus.analyzing).length}餐分析中',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: _Nutrient(
                          label: '蛋白质',
                          value: data.todayTotal.protein,
                        ),
                      ),
                      Expanded(
                        child: _Nutrient(
                          label: '碳水化合物',
                          value: data.todayTotal.carbs,
                        ),
                      ),
                      Expanded(
                        child: _Nutrient(
                          label: '脂肪',
                          value: data.todayTotal.fat,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '仅汇总已确认且有数值的记录，不代表全天摄入。',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeading(
                    title: '今天的餐食',
                    detail: '饮食历史',
                    onTap: () => context.push(AppRoutes.mealHistory),
                  ),
                  if (meals.isEmpty)
                    const InfoBanner(text: '今天还没有餐食记录，可以拍照或手工记录。'),
                  for (final meal in meals)
                    AppListRow(
                      title: meal.type.label,
                      subtitle: meal.title,
                      leading: const PlateIllustration(size: 44),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            meal.status == AnalysisStatus.ready
                                ? '${formatAmount(meal.nutrients.energy)} kcal'
                                : meal.status.label,
                            style: TextStyle(
                              color: meal.status == AnalysisStatus.ready
                                  ? AppColors.ink
                                  : AppColors.amberInk,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            '查看详情',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => context.push(AppRoutes.mealDetail(meal.id)),
                    ),
                ],
              ),
            ),
          ],
          aside: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(title: '下一步，轻松一点'),
                  const SizedBox(height: 12),
                  const Text(
                    '午餐的鱼吃了多少？',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '核对实际份量，让记录更接近你吃下的这一餐。',
                    style: TextStyle(color: AppColors.muted, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: '核对午餐',
                    secondary: true,
                    onPressed: () =>
                        context.push(AppRoutes.mealDetail('lunch')),
                  ),
                ],
              ),
            ),
            AppCard(
              child: Column(
                children: [
                  AppListRow(
                    title: '本周营养报告',
                    subtitle: '6个记录日 · 保留缺失日',
                    leading: Icon(AppIcons.reports),
                    onTap: () => context.push(AppRoutes.reports),
                  ),
                  AppListRow(
                    title: '健康档案',
                    subtitle: '查看过敏与饮食限制',
                    leading: const Icon(Icons.folder_outlined),
                    onTap: () => context.push(AppRoutes.healthRecords),
                  ),
                  if (institution)
                    AppListRow(
                      title: '食堂菜单',
                      subtitle: '计划与实际摄入分别记录',
                      leading: Icon(AppIcons.plan),
                      onTap: () => context.push(AppRoutes.institutionMenu),
                    ),
                ],
              ),
            ),
            if (institution)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeading(title: '补充一餐'),
                    const SizedBox(height: 8),
                    AppListRow(
                      title: '拍照记录',
                      subtitle: '演示图片采集',
                      leading: Icon(AppIcons.camera),
                      onTap: () => context.push(AppRoutes.capture),
                    ),
                    AppListRow(
                      title: '手工记录',
                      leading: const Icon(Icons.edit_outlined),
                      onTap: () => context.push(AppRoutes.manualMeal),
                    ),
                  ],
                ),
              ),
            const InfoBanner(text: '饮食质量暂未评估。记录不完整时，不计算评分或推断全天营养缺口。'),
          ],
        ),
      ],
    );
  }
}

class _Nutrient extends StatelessWidget {
  const _Nutrient({required this.label, required this.value});
  final String label;
  final double? value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 6),
      Text(
        '${formatAmount(value, unknown: '—')} g',
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
      ),
    ],
  );
}
