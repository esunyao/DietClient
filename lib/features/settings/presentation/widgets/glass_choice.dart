import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';

/// 展示并选择玻璃档位；预览复用共享背景与镜片组件，不自行判断渲染能力。
class GlassChoice extends StatelessWidget {
  const GlassChoice({
    super.key,
    required this.mode,
    required this.selected,
    required this.reduceTransparency,
    required this.onTap,
    required this.width,
  });

  final GlassMode mode;
  final bool selected;
  final bool reduceTransparency;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? AppColors.surfaceMuted : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 94,
                width: double.infinity,
                // 在有界插画背景上叠加独立镜片，并将透明度偏好传给两者。
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
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: GlassSurface(
                        mode: mode,
                        reduceTransparency: reduceTransparency,
                        radius: 14,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 9,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Icon(AppIcons.home, size: 17),
                              Icon(AppIcons.plan, size: 17),
                              Icon(AppIcons.profile, size: 17),
                            ],
                          ),
                        ),
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
                fontSize: 15,
                color: selected ? AppColors.primary : AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              switch (mode) {
                GlassMode.off => '实体表面',
                GlassMode.standard => '轻量磨砂',
                GlassMode.enhanced => '支持时折射',
              },
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
