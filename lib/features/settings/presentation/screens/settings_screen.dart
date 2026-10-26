import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/ui_preferences.dart';
import '../../../../core/presentation/display_state.dart';
import '../../../../demo/demo_store.dart';
import '../../../../core/config/ui_preview_config.dart';
import '../widgets/glass_choice.dart';
import '../widgets/meal_history_layout_choice.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final native = !ref.read(uiPreviewProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(native ? '恢复默认外观？' : '恢复初始演示？'),
        content: Text(
          native
              ? '恢复紧凑列表及默认玻璃、透明度和动态效果；餐食、健康资料、授权和登录会话保持不变。'
              : '本次尚未持久化的演示修改与外观偏好将清除。不会退出真实登录会话。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (ref.read(uiPreviewProvider)) ref.read(demoProvider.notifier).reset();
    await ref.read(uiPreferencesProvider.notifier).reset();
    if (!context.mounted) return;
    final result = ref.read(uiPreferencesProvider);
    showDemoMessage(
      context,
      result.error ?? (native ? '已恢复默认外观' : '内存演示已恢复初始样例'),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final native = !ref.watch(uiPreviewProvider);
    final prefs = ref.watch(uiPreferencesProvider);
    final controller = ref.read(uiPreferencesProvider.notifier);
    final preview = ref.watch(uiPreviewProvider);
    final institution = preview
        ? ref.watch(demoProvider.select((s) => s.isInstitution))
        : ref.watch(displayStateProvider.select((s) => s.isInstitution));
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final history = AppCard(
      radius: wide ? 16 : 20,
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
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final layout in MealHistoryLayout.values)
                    MealHistoryLayoutChoice(
                      width: width,
                      layout: layout,
                      selected: prefs.mealHistoryLayout == layout,
                      onTap: prefs.loading || prefs.saving
                          ? null
                          : () => controller.setMealHistoryLayout(layout),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
    final glass = AppCard(
      radius: wide ? 16 : 20,
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
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 12,
                children: [
                  for (final mode in GlassMode.values)
                    GlassChoice(
                      width: width,
                      mode: mode,
                      selected: prefs.glassMode == mode,
                      reduceTransparency: prefs.reduceTransparency,
                      onTap: () => controller.setGlassMode(mode),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            prefs.reduceTransparency
                ? '已减少透明度，预览使用实体表面。'
                : prefs.glassMode == GlassMode.enhanced &&
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
    final accessibility = AppCard(
      radius: wide ? 16 : 20,
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
            value: prefs.reduceTransparency,
            onChanged: controller.setReduceTransparency,
          ),
          const Divider(height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('减少动态效果', style: TextStyle(fontSize: 15)),
            subtitle: const Text(
              '同时遵循系统减少动态效果设置',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            value: prefs.reduceMotion,
            onChanged: controller.setReduceMotion,
          ),
        ],
      ),
    );
    final experience = AppCard(
      radius: wide ? 16 : 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(title: '体验模式'),
          const SizedBox(height: 16),
          AppSegmented(
            labels: const ['个人', '机构内个人'],
            selected: institution ? 1 : 0,
            onChanged: (index) {
              final mode = index == 0
                  ? ExperienceMode.personal
                  : ExperienceMode.institution;
              if (preview) {
                ref.read(demoProvider.notifier).selectMode(mode);
              } else {
                ref.read(displayStateProvider.notifier).selectMode(mode);
              }
              showDemoMessage(
                context,
                native ? '已切换显示模式，不代表机构身份或机构授权' : '已切换演示模式，内存数据恢复初始样例',
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            native
                ? '模式由你选择，仅改变本机显示，不赋予机构身份；个人信息遮罩为临时显示设置。'
                : '模式由你选择。窗口大小只改变布局；机构模式依然只显示本人信息。切换后内存数据恢复初始样例。',
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.7),
          ),
          if (institution) ...[
            const SizedBox(height: 16),
            AppButton(
              label: '暂时隐藏个人信息',
              icon: AppIcons.shield,
              secondary: true,
              onPressed: () {
                if (preview) {
                  ref.read(demoProvider.notifier).setPrivacyHidden(true);
                } else {
                  ref
                      .read(displayStateProvider.notifier)
                      .setPrivacyHidden(true);
                }
              },
            ),
          ],
        ],
      ),
    );
    final reset = AppCard(
      radius: wide ? 16 : 20,
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
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.7),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: native ? '恢复默认外观' : '恢复初始演示',
            secondary: true,
            onPressed: prefs.loading || prefs.saving
                ? null
                : () => _reset(context, ref),
          ),
        ],
      ),
    );
    return AppPage(
      demoLabel: preview ? '设计样例 · 演示数据' : null,
      title: native ? '外观设置' : '外观与演示设置',
      showBack: true,
      children: [
        if (prefs.loading || prefs.saving) const LinearProgressIndicator(),
        if (prefs.error != null) ...[
          InfoBanner(text: prefs.error!, color: AppColors.red),
          TextButton(
            onPressed: controller.reload,
            child: const Text('重新读取外观设置'),
          ),
        ],
        AbsorbPointer(
          absorbing: prefs.loading || prefs.saving,
          child: AdaptiveColumns(
            main: [history, glass, accessibility],
            aside: [experience, reset],
          ),
        ),
        Text(
          native
              ? '${ref.watch(persistentUiPreferencesProvider) ? '外观偏好保存在本机' : '外观偏好仅保留在本次会话'}；模式选择和信息遮罩为临时显示，不修改账户、登录会话或授权。'
              : '外观偏好与业务样例仅保留在内存，不修改真实账户、登录会话或授权。',
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.7),
        ),
      ],
    );
  }
}
