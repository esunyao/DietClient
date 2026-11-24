import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/ui_preview_config.dart';
import '../../../../core/presentation/display_state.dart';
import '../../../../core/presentation/ui_preferences.dart';
import '../../../../demo/demo_store.dart';
import '../../application/settings_manager.dart';
import '../widgets/glass_choice.dart';
import '../widgets/meal_history_layout_choice.dart';

/// 应用外观与显示模式设置页面。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final native = !ref.read(uiPreviewProvider);
    final confirmed = await showAppConfirmDialog(
      context,
      title: native ? '恢复默认外观？' : '恢复初始演示？',
      content: native
          ? '恢复紧凑列表及默认玻璃、透明度和动态效果；餐食、健康资料、授权和登录会话保持不变。'
          : '本次尚未持久化的演示修改与外观偏好将清除。不会退出真实登录会话。',
      confirmLabel: '恢复',
      filledConfirm: true,
    );
    if (!confirmed || !context.mounted) return;
    final message = await ref.read(settingsManagerProvider).resetDefaults();
    if (!context.mounted) return;
    showDemoMessage(context, message);
  }

  void _selectMode(BuildContext context, WidgetRef ref, int index) {
    final native = !ref.read(uiPreviewProvider);
    final mode = index == 0
        ? ExperienceMode.personal
        : ExperienceMode.institution;
    ref.read(settingsManagerProvider).selectExperienceMode(mode);
    showDemoMessage(
      context,
      native ? '已切换显示模式，不代表机构身份或机构授权' : '已切换演示模式，内存数据恢复初始样例',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(uiPreviewProvider);
    final native = !preview;
    final prefs = ref.watch(uiPreferencesProvider);
    final manager = ref.read(settingsManagerProvider);
    // 体验模式由演示状态或真实临时显示状态显式持有，不按窗口宽度自动推断。
    final institution = preview
        ? ref.watch(demoProvider.select((s) => s.isInstitution))
        : ref.watch(displayStateProvider.select((s) => s.isInstitution));
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final cardRadius = wide ? 16.0 : 20.0;

    return AppPage(
      demoLabel: preview ? '设计样例 · 演示数据' : null,
      title: native ? '外观设置' : '外观与演示设置',
      showBack: true,
      children: [
        // 加载或保存偏好期间禁用表单交互，错误时保留重新读取入口。
        if (prefs.loading || prefs.saving) const LinearProgressIndicator(),
        if (prefs.error != null) ...[
          InfoBanner(text: prefs.error!, color: AppColors.red),
          TextButton(
            onPressed: manager.reloadPreferences,
            child: const Text('重新读取外观设置'),
          ),
        ],
        AbsorbPointer(
          absorbing: prefs.loading || prefs.saving,
          child: AdaptiveColumns(
            main: [
              _HistoryLayoutCard(
                radius: cardRadius,
                selectedLayout: prefs.mealHistoryLayout,
                locked: prefs.isBusy,
                onSelect: manager.setMealHistoryLayout,
              ),
              _GlassEffectCard(
                radius: cardRadius,
                selectedMode: prefs.glassMode,
                reduceTransparency: prefs.reduceTransparency,
                onSelect: manager.setGlassMode,
              ),
              _AccessibilityCard(
                radius: cardRadius,
                reduceTransparency: prefs.reduceTransparency,
                reduceMotion: prefs.reduceMotion,
                onReduceTransparencyChanged: manager.setReduceTransparency,
                onReduceMotionChanged: manager.setReduceMotion,
              ),
            ],
            aside: [
              _ExperienceModeCard(
                radius: cardRadius,
                native: native,
                institution: institution,
                onSelectIndex: (index) => _selectMode(context, ref, index),
                onHidePrivacy: () => manager.setPrivacyHidden(true),
              ),
              _ResetAppearanceCard(
                radius: cardRadius,
                native: native,
                disabled: prefs.isBusy,
                onReset: () => _reset(context, ref),
              ),
            ],
          ),
        ),
        Text(
          native
              ? '${ref.watch(persistentUiPreferencesProvider) ? '外观偏好保存在本机' : '外观偏好仅保留在本次会话'}；模式选择和信息遮罩为临时显示，不修改账户、登录会话或授权。'
              : '外观偏好与业务样例仅保留在内存，不修改真实账户、登录会话或授权。',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            height: 1.7,
          ),
        ),
      ],
    );
  }
}

class _HistoryLayoutCard extends StatelessWidget {
  const _HistoryLayoutCard({
    required this.radius,
    required this.selectedLayout,
    required this.locked,
    required this.onSelect,
  });

  final double radius;
  final MealHistoryLayout selectedLayout;
  final bool locked;
  final ValueChanged<MealHistoryLayout> onSelect;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: radius,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(title: '饮食历史显示方式'),
        const SizedBox(height: 8),
        const Text(
          '选择历史餐食的浏览布局',
          style: TextStyle(color: AppColors.muted, fontSize: 14),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 340 ? 2 : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final layout in MealHistoryLayout.values)
                  MealHistoryLayoutChoice(
                    width: width,
                    layout: layout,
                    selected: selectedLayout == layout,
                    onTap: locked ? null : () => onSelect(layout),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _GlassEffectCard extends StatelessWidget {
  const _GlassEffectCard({
    required this.radius,
    required this.selectedMode,
    required this.reduceTransparency,
    required this.onSelect,
  });

  final double radius;
  final GlassMode selectedMode;
  final bool reduceTransparency;
  final ValueChanged<GlassMode> onSelect;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: radius,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(title: '玻璃效果'),
        const SizedBox(height: 8),
        const Text(
          '在导航和浮层预览效果',
          style: TextStyle(color: AppColors.muted, fontSize: 14),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 290 ? 3 : 1;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 12,
              children: [
                for (final mode in GlassMode.values)
                  GlassChoice(
                    width: width,
                    mode: mode,
                    selected: selectedMode == mode,
                    reduceTransparency: reduceTransparency,
                    onTap: () => onSelect(mode),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          reduceTransparency
              ? '已减少透明度，预览使用实体表面。'
              : selectedMode == GlassMode.enhanced &&
                    !GlassSurface.supportsEnhanced
              ? '当前平台使用标准磨砂回退；增强折射需支持的渲染器或 Windows 真实背景捕获。'
              : '标准为轻量磨砂，不是增强折射。增强不可用或加载失败时自动回退。',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            height: 1.7,
          ),
        ),
      ],
    ),
  );
}

class _AccessibilityCard extends StatelessWidget {
  const _AccessibilityCard({
    required this.radius,
    required this.reduceTransparency,
    required this.reduceMotion,
    required this.onReduceTransparencyChanged,
    required this.onReduceMotionChanged,
  });

  final double radius;
  final bool reduceTransparency;
  final bool reduceMotion;
  final ValueChanged<bool> onReduceTransparencyChanged;
  final ValueChanged<bool> onReduceMotionChanged;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: radius,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(title: '阅读与动态'),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('减少透明度', style: TextStyle(fontSize: 15)),
          subtitle: const Text(
            '导航与浮层使用不透明表面',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          value: reduceTransparency,
          onChanged: onReduceTransparencyChanged,
        ),
        const Divider(height: 1),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('减少动态效果', style: TextStyle(fontSize: 15)),
          subtitle: const Text(
            '同时遵循系统减少动态效果设置',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          value: reduceMotion,
          onChanged: onReduceMotionChanged,
        ),
      ],
    ),
  );
}

class _ExperienceModeCard extends StatelessWidget {
  const _ExperienceModeCard({
    required this.radius,
    required this.native,
    required this.institution,
    required this.onSelectIndex,
    required this.onHidePrivacy,
  });

  final double radius;
  final bool native;
  final bool institution;
  final ValueChanged<int> onSelectIndex;
  final VoidCallback onHidePrivacy;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: radius,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading(title: '体验模式'),
        const SizedBox(height: 16),
        AppSegmented(
          labels: const ['个人', '机构内个人'],
          selected: institution ? 1 : 0,
          onChanged: onSelectIndex,
        ),
        const SizedBox(height: 12),
        Text(
          native
              ? '模式由你选择，仅改变本机显示，不赋予机构身份；个人信息遮罩为临时显示设置。'
              : '模式由你选择。窗口大小只改变布局；机构模式依然只显示本人信息。切换后内存数据恢复初始样例。',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            height: 1.7,
          ),
        ),
        if (institution) ...[
          const SizedBox(height: 16),
          AppButton(
            label: '暂时隐藏个人信息',
            icon: AppIcons.shield,
            secondary: true,
            onPressed: onHidePrivacy,
          ),
        ],
      ],
    ),
  );
}

class _ResetAppearanceCard extends StatelessWidget {
  const _ResetAppearanceCard({
    required this.radius,
    required this.native,
    required this.disabled,
    required this.onReset,
  });

  final double radius;
  final bool native;
  final bool disabled;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: radius,
    color: AppColors.surfaceMuted,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(title: native ? '重置外观' : '重置演示'),
        const SizedBox(height: 12),
        Text(
          native
              ? '恢复紧凑列表及默认玻璃、透明度和动态效果，不清除餐食、健康资料、授权或会话。'
              : '清除本次内存里的编辑、计划、授权预览与报告版本，恢复初始样例。',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: native ? '恢复默认外观' : '恢复初始演示',
          secondary: true,
          onPressed: disabled ? null : onReset,
        ),
      ],
    ),
  );
}
