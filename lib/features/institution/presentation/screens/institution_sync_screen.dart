import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/ui_preview_config.dart';
import '../../../../core/presentation/unsupported_feature_page.dart';
import '../../../../demo/demo_store.dart';

/// 机构餐食同步核对演示页面，原生营养模式下展示暂未支持说明。
class InstitutionSyncScreen extends ConsumerStatefulWidget {
  const InstitutionSyncScreen({super.key});

  @override
  ConsumerState<InstitutionSyncScreen> createState() =>
      _InstitutionSyncScreenState();
}

class _InstitutionSyncScreenState extends ConsumerState<InstitutionSyncScreen> {
  // 归属与食用比例为局部选项；限制核对和确认入账状态由共享演示 store 管理。
  int _ownership = 0;
  double? _fraction;

  void _confirmMeal() {
    ref
        .read(demoProvider.notifier)
        .confirmInstitutionMeal(fraction: _fraction!);
    showDemoMessage(context, '已更新本次演示中的实际摄入、趋势及报告更新状态。');
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(nativeNutritionEnabledProvider)) {
      return const UnsupportedFeaturePage(
        title: '机构餐食同步',
        description: '机构餐食同步与摄入确认暂未支持。不会将机构样例计入个人真实摄入。',
      );
    }
    final state = ref.watch(demoProvider);
    final plan = demoPlans.first;
    final canConfirm =
        _ownership == 1 &&
        _fraction != null &&
        state.restrictionChecked &&
        !state.institutionConfirmed;

    return AppPage(
      demoLabel: '设计样例 · 演示数据',
      title: '核对这份机构餐食',
      subtitle: '青禾园区 · 一号食堂 · 同步与实际摄入确认演示',
      showBack: true,
      children: [
        AdaptiveColumns(
          main: [
            _SyncStatusCard(
              confirmed: state.institutionConfirmed,
              ownership: _ownership,
              planName: plan.name,
              onMarkMismatch: () => setState(() => _ownership = 2),
            ),
            // 标记为误归属后隐藏其他人的菜品细节，转为提示联系机构复核。
            if (_ownership != 2) ...[
              const SectionHeading(title: '机构提供的菜品'),
              _InstitutionFoodsCard(foods: plan.foods),
            ] else
              const InfoBanner(
                color: AppColors.amberInk,
                icon: AppIcons.warning,
                text: '已标记误归属，暂停入账。演示中不展示其他人的餐食详情；请联系机构复核关联。',
              ),
            const AppCard(
              radius: 16,
              color: AppColors.greenSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('数据来源：机构菜单配方 v1（演示）', style: TextStyle(fontSize: 14)),
                  SizedBox(height: 10),
                  Text(
                    '标准营养不等于实际吃下的营养，需本人确认。',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
          aside: [
            _SyncConfirmationAsideCard(
              ownership: _ownership,
              fraction: _fraction,
              plan: plan,
              restrictionChecked: state.restrictionChecked,
              institutionConfirmed: state.institutionConfirmed,
              canConfirm: canConfirm,
              onOwnershipChanged: (value) => setState(() => _ownership = value),
              onFractionSelected: (amount) =>
                  setState(() => _fraction = amount),
              onConfirm: _confirmMeal,
            ),
            InfoBanner(
              icon: AppIcons.shieldCheck,
              text: state.institutionConfirmed
                  ? '确认成功后\n已形成同一本人本餐记录，首页与趋势同步更新，旧报告保留原版本。'
                  : '这条记录暂不进入统计\n餐号只用于关联本餐。确认归属、食用量及限制核对后方可记录；重复确认不会重复创建餐食。',
            ),
            AppCard(
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '已模拟核对过敏配料与交叉接触',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: const Text(
                  '仅本地演示，非真实食物安全确认',
                  style: TextStyle(fontSize: 12),
                ),
                value: state.restrictionChecked,
                onChanged: state.institutionConfirmed
                    ? null
                    : (value) => ref
                          .read(demoProvider.notifier)
                          .setRestrictionChecked(value ?? false),
              ),
            ),
            const AppCard(
              radius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeading(title: '异常情况与处理'),
                  SizedBox(height: 12),
                  Text(
                    '归属不明或关联错误：停止入账，联系机构复核。\n\n餐号过期或同步失败：重新获取来源，不以演示菜单替代真实结果。\n\n过敏规则冲突：联系食堂或专业人员，未解决前暂停确认。',
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

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({
    required this.confirmed,
    required this.ownership,
    required this.planName,
    required this.onMarkMismatch,
  });

  final bool confirmed;
  final int ownership;
  final String planName;
  final VoidCallback onMarkMismatch;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: 16,
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            const Text(
              '10月2日晚餐',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            AppBadge(
              label: confirmed ? '已核对入账 · 演示' : '待本人确认',
              color: confirmed ? AppColors.primary : AppColors.amberInk,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          '17:35同步 · 餐号 QH-1002-017 · 仅限本人核对',
          style: TextStyle(color: AppColors.muted, fontSize: 14),
        ),
        const Divider(height: 32),
        Text(
          confirmed ? '已形成实际用餐记录' : '机构记录已到达',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                confirmed
                    ? '同一本人本餐记录不会重复创建。'
                    : ownership == 2
                    ? '已标记误归属，暂停入账并等待机构复核。'
                    : '关联$planName，尚未写入实际摄入。',
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(onPressed: onMarkMismatch, child: const Text('归属有误')),
          ],
        ),
      ],
    ),
  );
}

class _InstitutionFoodsCard extends StatelessWidget {
  const _InstitutionFoodsCard({required this.foods});

  final List<FoodPortion> foods;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: 16,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
    child: Column(
      children: [
        for (var i = 0; i < foods.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: const PlateIllustration(size: 42),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        foods[i].name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${formatAmount(foods[i].grams)} g / 机构配方样例',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '标准份量',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (i < foods.length - 1) const Divider(height: 1, indent: 64),
        ],
      ],
    ),
  );
}

class _SyncConfirmationAsideCard extends StatelessWidget {
  const _SyncConfirmationAsideCard({
    required this.ownership,
    required this.fraction,
    required this.plan,
    required this.restrictionChecked,
    required this.institutionConfirmed,
    required this.canConfirm,
    required this.onOwnershipChanged,
    required this.onFractionSelected,
    required this.onConfirm,
  });

  final int ownership;
  final double? fraction;
  final PlanOption plan;
  final bool restrictionChecked;
  final bool institutionConfirmed;
  final bool canConfirm;
  final ValueChanged<int> onOwnershipChanged;
  final ValueChanged<double> onFractionSelected;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: 16,
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading(title: '确认前，请先核对'),
        const SizedBox(height: 18),
        const Text(
          '这是我的餐食',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        AppSegmented(
          labels: const ['待确认', '是我的', '不是我的'],
          selected: ownership,
          equalWidth: true,
          onChanged: onOwnershipChanged,
        ),
        const SizedBox(height: 20),
        const Text(
          '实际食用量',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final amount in [0.25, 0.5, 0.75, 1.0])
              ChoiceChip(
                label: Text(
                  amount == 1 ? '全部吃完' : '${(amount * 100).round()}%',
                ),
                selected: fraction == amount,
                showCheckmark: false,
                onSelected: (_) => onFractionSelected(amount),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '按整套餐相同比例食用的演示；未填写时不默认吃完。',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Text(
          fraction == null
              ? '未填写食用量；标准套餐预计 ${formatAmount(plan.energy)} kcal'
              : '按所选比例预计 ${formatAmount(plan.energy * fraction!)} kcal / 蛋白质 ${formatAmount(plan.protein * fraction!)} g',
          style: const TextStyle(color: AppColors.muted, fontSize: 14),
        ),
        if (!restrictionChecked)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              '过敏配料与交叉接触尚未核对，请在下方明确完成演示核对后再确认。',
              style: TextStyle(color: AppColors.amberInk, fontSize: 12),
            ),
          ),
        const SizedBox(height: 18),
        AppButton(
          label: institutionConfirmed ? '已记录，避免重复确认' : '确认归属与食用量后记录',
          onPressed: canConfirm ? onConfirm : null,
        ),
      ],
    ),
  );
}
