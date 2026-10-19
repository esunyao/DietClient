import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/core/presentation/app_routes.dart';
import 'package:diet_client/demo/demo_store.dart';

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
    final state = ref.watch(demoProvider);
    final plan = demoPlans.firstWhere((p) => p.id == _selection);
    return AppPage(
      title: '今晚，食堂有什么',
      subtitle: '青禾园区 · 一号食堂 · 10月2日菜单与点餐演示',
      showBack: true,
      children: [
        AdaptiveColumns(
          main: [
            AppSegmented(
              labels: const ['早餐', '午餐', '晚餐'],
              selected: _meal,
              onChanged: (value) => setState(() {
                _meal = value;
                _submitted = false;
              }),
            ),
            Text(_meal == 2 ? '供应时段 17:30—19:00' : '该餐别未提供演示菜单'),
            if (_meal == 2) ...[
              const SectionHeading(title: '今日可选套餐'),
              AppCard(
                child: Column(
                  children: [
                    for (final option in demoPlans)
                      AppListRow(
                        title: option.name,
                        subtitle:
                            '${option.foods.map((f) => f.name).join(' / ')}\n${formatAmount(option.energy)} kcal · 蛋白质 ${formatAmount(option.protein)} g / 标准套餐',
                        leading: const PlateIllustration(size: 54),
                        trailing: Icon(
                          _selection == option.id
                              ? Icons.check_circle_outline
                              : Icons.add_circle_outline,
                          color: AppColors.primary,
                        ),
                        onTap: () => setState(() {
                          _selection = option.id;
                          _submitted = false;
                        }),
                      ),
                  ],
                ),
              ),
              const InfoBanner(
                color: AppColors.amberSoft,
                icon: Icons.warning_amber_outlined,
                text: '先核实过敏条件\n已登记花生过敏，配料与交叉接触尚待食堂确认。无法核实时暂停确认并联系食堂或专业人员。',
              ),
              AppCard(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('模拟完成食堂配料与交叉接触核对'),
                  subtitle: const Text('仅解除本地演示阻挡，不代表真实食物安全确认'),
                  value: state.restrictionChecked,
                  onChanged: (value) {
                    ref
                        .read(demoProvider.notifier)
                        .setRestrictionChecked(value ?? false);
                    setState(() => _submitted = false);
                  },
                ),
              ),
            ],
            const SectionHeading(title: '供应与版本'),
            const AppCard(
              child: Text(
                '菜单采用当日配方 v1（演示）。标准营养是整套餐预计值；停售或撤回菜品不可继续选择。选餐结果与实际食用记录分开处理。',
              ),
            ),
          ],
          aside: [
            if (_meal == 2)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeading(title: '本次选餐'),
                    const SizedBox(height: 12),
                    AppBadge(label: _submitted ? '已提交 · 演示' : '未提交'),
                    const SizedBox(height: 12),
                    Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    for (final food in plan.foods)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${food.name} ${formatAmount(food.grams)} g',
                        ),
                      ),
                    const Divider(height: 32),
                    Text(
                      '${formatAmount(plan.energy)} kcal / 预计',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text('蛋白质 ${formatAmount(plan.protein)} g · 1份标准套餐'),
                    const SizedBox(height: 16),
                    AppButton(
                      label: '联系食堂核实',
                      secondary: true,
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
                    ),
                    const SizedBox(height: 12),
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
            AppButton(
              label: '查看机构餐食同步',
              secondary: true,
              onPressed: () => context.push(AppRoutes.institutionSync),
            ),
          ],
        ),
      ],
    );
  }
}
