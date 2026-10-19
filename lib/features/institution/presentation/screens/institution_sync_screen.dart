import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/demo/demo_store.dart';

class InstitutionSyncScreen extends ConsumerStatefulWidget {
  const InstitutionSyncScreen({super.key});
  @override
  ConsumerState<InstitutionSyncScreen> createState() =>
      _InstitutionSyncScreenState();
}

class _InstitutionSyncScreenState extends ConsumerState<InstitutionSyncScreen> {
  int _ownership = 0;
  double? _fraction;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(demoProvider);
    final plan = demoPlans.first;
    final canConfirm =
        _ownership == 1 &&
        _fraction != null &&
        state.restrictionChecked &&
        !state.institutionConfirmed;
    return AppPage(
      title: '核对这份机构餐食',
      subtitle: '青禾园区 · 一号食堂 · 同步与实际摄入确认演示',
      showBack: true,
      children: [
        AdaptiveColumns(
          main: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '10月2日晚餐',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  AppBadge(
                    label: state.institutionConfirmed ? '已核对入账 · 演示' : '待本人确认',
                  ),
                  const SizedBox(height: 12),
                  const Text('17:35同步 · 餐号 QH-1002-017 · 仅限本人核对'),
                  const Divider(height: 32),
                  Text(
                    state.institutionConfirmed
                        ? '已形成实际用餐记录，不会重复创建。'
                        : '机构记录已到达，尚未写入实际摄入。',
                  ),
                ],
              ),
            ),
            if (_ownership != 2) ...[
              const SectionHeading(title: '机构提供的菜品'),
              AppCard(
                child: Column(
                  children: [
                    for (final food in plan.foods)
                      AppListRow(
                        title: food.name,
                        subtitle: '${formatAmount(food.grams)} g / 机构配方样例',
                        leading: const PlateIllustration(size: 48),
                        trailing: const Text('标准份量'),
                      ),
                  ],
                ),
              ),
            ] else
              const InfoBanner(
                color: AppColors.amberSoft,
                text: '已标记误归属，暂停入账。演示中不展示其他人的餐食详情；请联系机构复核关联。',
              ),
            const InfoBanner(text: '数据来源：机构菜单配方 v1（演示）\n标准营养不等于实际吃下的营养，需本人确认。'),
            const SectionHeading(title: '异常情况与处理'),
            const AppCard(
              child: Text(
                '归属不明或关联错误：停止入账，联系机构复核。\n\n餐号过期或同步失败：重新获取来源，不以演示菜单替代真实结果。\n\n过敏规则冲突：联系食堂或专业人员，未解决前暂停确认。',
              ),
            ),
          ],
          aside: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(title: '确认前，请先核对'),
                  const SizedBox(height: 16),
                  const Text(
                    '这是我的餐食',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  AppSegmented(
                    labels: const ['待确认', '是我的', '不是我的'],
                    selected: _ownership,
                    onChanged: (value) => setState(() => _ownership = value),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '实际食用量',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final amount in [0.25, 0.5, 0.75, 1.0])
                        ChoiceChip(
                          label: Text('${(amount * 100).round()}%'),
                          selected: _fraction == amount,
                          onSelected: (_) => setState(() => _fraction = amount),
                        ),
                    ],
                  ),
                  const Text(
                    '按整套餐相同比例食用的演示；未填写时不默认吃完。',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('已模拟核对过敏配料与交叉接触'),
                    subtitle: const Text('仅本地演示，非真实食物安全确认'),
                    value: state.restrictionChecked,
                    onChanged: state.institutionConfirmed
                        ? null
                        : (value) => ref
                              .read(demoProvider.notifier)
                              .setRestrictionChecked(value ?? false),
                  ),
                  Text(
                    _fraction == null
                        ? '未填写食用量；标准套餐预计 520 kcal'
                        : '按所选比例预计 ${formatAmount(plan.energy * _fraction!)} kcal / 蛋白质 ${formatAmount(plan.protein * _fraction!)} g',
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: state.institutionConfirmed
                        ? '已记录，避免重复确认'
                        : '确认归属与食用量后记录',
                    onPressed: canConfirm
                        ? () {
                            ref
                                .read(demoProvider.notifier)
                                .confirmInstitutionMeal(fraction: _fraction!);
                            showDemoMessage(
                              context,
                              '已更新本次演示中的实际摄入、趋势及报告更新状态。',
                            );
                          }
                        : null,
                  ),
                ],
              ),
            ),
            InfoBanner(
              text: state.institutionConfirmed
                  ? '确认成功后\n已形成同一本人本餐记录，首页与趋势同步更新，旧报告保留原版本。'
                  : '这条记录暂不进入统计\n确认归属、食用量及限制核对后方可记录；重复确认不会重复创建餐食。',
            ),
          ],
        ),
      ],
    );
  }
}
