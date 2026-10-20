import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/ui_preferences.dart';
import '../../../../demo/demo_store.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(uiPreferencesProvider);
    final controller = ref.read(uiPreferencesProvider.notifier);
    final demo = ref.watch(demoProvider);
    return AppPage(
      title: '外观与演示设置',
      showBack: true,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(title: '玻璃效果'),
              const SizedBox(height: 8),
              const Text(
                '在导航和浮层预览效果',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final mode in GlassMode.values)
                    _GlassChoice(
                      mode: mode,
                      selected: prefs.glassMode == mode,
                      reduceTransparency: prefs.reduceTransparency,
                      onTap: () => controller.setGlassMode(mode),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                prefs.glassMode == GlassMode.enhanced &&
                        !GlassSurface.supportsEnhanced
                    ? '当前平台使用标准磨砂回退；增强需支持的渲染器或 Windows 背景捕获。'
                    : '标准使用轻量磨砂。增强加载失败时自动回退。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('减少透明度'),
                subtitle: const Text('导航与浮层使用不透明表面'),
                value: prefs.reduceTransparency,
                onChanged: controller.setReduceTransparency,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('减少动态效果'),
                subtitle: const Text('同时遵循系统减少动态效果设置'),
                value: prefs.reduceMotion,
                onChanged: controller.setReduceMotion,
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(title: '体验模式'),
              const SizedBox(height: 12),
              AppSegmented(
                labels: const ['个人', '机构内个人'],
                selected: demo.isInstitution ? 1 : 0,
                onChanged: (index) {
                  ref
                      .read(demoProvider.notifier)
                      .selectMode(
                        index == 0
                            ? ExperienceMode.personal
                            : ExperienceMode.institution,
                      );
                  showDemoMessage(context, '已切换演示模式，内存数据恢复初始样例');
                },
              ),
              const SizedBox(height: 12),
              const Text(
                '模式由你选择。窗口大小只改变布局；机构模式依然只显示本人信息。',
                style: TextStyle(color: AppColors.muted, height: 1.6),
              ),
              if (demo.isInstitution)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: AppButton(
                    label: '暂时隐藏个人信息',
                    icon: Icons.visibility_off_outlined,
                    secondary: true,
                    onPressed: () =>
                        ref.read(demoProvider.notifier).setPrivacyHidden(true),
                  ),
                ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(title: '重置演示'),
              const SizedBox(height: 8),
              const Text(
                '清除本次内存里的编辑、计划、授权预览与报告版本，恢复初始样例。',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: '恢复初始演示',
                secondary: true,
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('恢复初始演示？'),
                      content: const Text('本次尚未持久化的演示修改将清除。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('恢复'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !context.mounted) return;
                  ref.read(demoProvider.notifier).reset();
                  controller.reset();
                  showDemoMessage(context, '内存演示已恢复初始样例');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassChoice extends StatelessWidget {
  const _GlassChoice({
    required this.mode,
    required this.selected,
    required this.reduceTransparency,
    required this.onTap,
  });
  final GlassMode mode;
  final bool selected;
  final bool reduceTransparency;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 142,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 94,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: GlassBackdrop(
                mode: mode,
                reduceTransparency: reduceTransparency,
                background: const ColoredBox(
                  color: AppColors.greenSoft,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: PlateIllustration(size: 54),
                  ),
                ),
                overlay: Align(
                  alignment: Alignment.bottomCenter,
                  child: GlassSurface(
                    mode: mode,
                    reduceTransparency: reduceTransparency,
                    radius: 14,
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Icon(Icons.home_outlined, size: 17),
                          Icon(Icons.restaurant_outlined, size: 17),
                          Icon(Icons.person_outline, size: 17),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              switch (mode) {
                GlassMode.off => '关闭',
                GlassMode.standard => '标准',
                GlassMode.enhanced => '增强',
              },
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
