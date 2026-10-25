import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/core/presentation/app_routes.dart';
import 'package:diet_client/demo/demo_store.dart';
import 'package:diet_client/core/config/ui_preview_config.dart';
import 'package:diet_client/core/presentation/unsupported_feature_page.dart';

class InstitutionMenuScreen extends ConsumerStatefulWidget {
  const InstitutionMenuScreen({super.key});
  @override
  ConsumerState<InstitutionMenuScreen> createState() =>
      _InstitutionMenuScreenState();
}

class _InstitutionMenuScreenState extends ConsumerState<InstitutionMenuScreen> {
  String _selection = demoPlans.first.id;
  bool _submitted = false;
  int _meal = 2;

  @override
  Widget build(BuildContext context) {
    if (ref.watch(nativeNutritionEnabledProvider)) {
      return const UnsupportedFeaturePage(
        title: '机构菜单',
        description: '机构菜单、选餐和过敏核对暂未支持。此处不会创建计划或餐食记录。',
      );
    }
    final state = ref.watch(demoProvider);
    final plan = demoPlans.firstWhere((p) => p.id == _selection);
    return AppPage(
      demoLabel: '设计样例 · 演示数据',
      title: '今晚，食堂有什么',
      subtitle: '青禾园区 · 一号食堂 · 10月2日菜单与点餐演示',
      showBack: true,
      children: [
        AdaptiveColumns(
          main: [
            LayoutBuilder(
              builder: (context, constraints) {
                final segments = AppSegmented(
                  labels: const ['早餐', '午餐', '晚餐'],
                  selected: _meal,
                  equalWidth: true,
                  onChanged: (value) => setState(() {
                    _meal = value;
                    _submitted = false;
                  }),
                );
                final supply = Text(
                  _meal == 2 ? '供应时段 17:30—19:00' : '该餐别未提供演示菜单',
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                );
                final wide =
                    MediaQuery.sizeOf(context).width >=
                    AppLayout.columnsMinWidth + AppLayout.wideGutter * 2;
                if (!wide ||
                    constraints.maxWidth <
                        600 * MediaQuery.textScalerOf(context).scale(14) / 14) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [segments, const SizedBox(height: 12), supply],
                  );
                }
                return Row(
                  children: [
                    SizedBox(width: 274, child: segments),
                    const Spacer(),
                    supply,
                  ],
                );
              },
            ),
            if (_meal == 2) ...[
              const SectionHeading(title: '今日可选套餐'),
              AppCard(
                radius: 16,
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (var i = 0; i < demoPlans.length; i++) ...[
                      Material(
                        color: _selection == demoPlans[i].id
                            ? AppColors.greenSoft
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => setState(() {
                            _selection = demoPlans[i].id;
                            _submitted = false;
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                const PlateIllustration(size: 58),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        demoPlans[i].name,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        demoPlans[i].foods
                                            .map((f) => f.name)
                                            .join(' / '),
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${formatAmount(demoPlans[i].energy)} kcal · 蛋白质 ${formatAmount(demoPlans[i].protein)} g / 标准套餐',
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  children: [
                                    Icon(
                                      _selection == demoPlans[i].id
                                          ? AppIcons.check
                                          : AppIcons.plus,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selection == demoPlans[i].id
                                          ? '已选'
                                          : '选择',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (i < demoPlans.length - 1)
                        const Divider(height: 1, indent: 90, endIndent: 12),
                    ],
                  ],
                ),
              ),
              const InfoBanner(
                color: AppColors.amberInk,
                icon: AppIcons.warning,
                text: '先核实过敏条件\n已登记花生过敏，配料与交叉接触尚待食堂确认。无法核实时暂停确认并联系食堂或专业人员。',
              ),
            ],
          ],
          aside: [
            if (_meal == 2)
              AppCard(
                radius: 16,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '本次选餐',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        AppBadge(label: _submitted ? '已提交 · 演示' : '未提交'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final food in plan.foods)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${food.name} ${formatAmount(food.grams)} g',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    const Divider(height: 32),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        Text(
                          formatAmount(plan.energy),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            'kcal / 预计',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '蛋白质 ${formatAmount(plan.protein)} g · 1 份标准套餐',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('食堂核对 · 演示'),
                            content: const Text(
                              '需核对花生配料、共用器具和交叉接触。此处不会拨打电话或发送消息；返回后可明确勾选模拟核对。',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('返回核对'),
                              ),
                            ],
                          ),
                        ),
                        child: const Text('联系食堂核实'),
                      ),
                    ),
                    AppButton(
                      label: _submitted
                          ? '已确认选餐（演示）'
                          : state.restrictionChecked
                          ? '确认选餐（演示）'
                          : '核实配料后确认选餐',
                      onPressed: !state.restrictionChecked || _submitted
                          ? null
                          : () => setState(() => _submitted = true),
                    ),
                  ],
                ),
              ),
            const InfoBanner(
              text: '选餐不等于已经吃完\n机构餐食到达后，核对本人归属与实际食用量，再记录摄入。此处选择不会改变今日合计。',
            ),
            if (_meal == 2)
              AppCard(
                radius: 16,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    '模拟完成食堂配料与交叉接触核对',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: const Text(
                    '仅解除本地演示阻挡，不代表真实食物安全确认',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: state.restrictionChecked,
                  onChanged: (value) {
                    ref
                        .read(demoProvider.notifier)
                        .setRestrictionChecked(value ?? false);
                    setState(() => _submitted = false);
                  },
                ),
              ),
            AppButton(
              label: '查看机构餐食同步',
              secondary: true,
              onPressed: () => context.push(AppRoutes.institutionSync),
            ),
            const AppCard(
              radius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeading(title: '供应与版本'),
                  SizedBox(height: 12),
                  Text(
                    '菜单采用当日配方 v1（演示）。标准营养是整套餐预计值；停售或撤回菜品不可继续选择。选餐结果与实际食用记录分开处理。',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
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
