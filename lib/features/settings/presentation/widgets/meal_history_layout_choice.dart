import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';

import '../../../../core/presentation/ui_preferences.dart';

class MealHistoryLayoutChoice extends StatelessWidget {
  const MealHistoryLayoutChoice({
    super.key,
    required this.layout,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  final MealHistoryLayout layout;
  final bool selected;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final compact = layout == MealHistoryLayout.compact;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceMuted : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: _LayoutPreview(compact: compact)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      compact ? '紧凑列表' : '照片卡片',
                      style: TextStyle(
                        color: selected ? AppColors.primary : AppColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ExcludeSemantics(
                    child: Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      size: 20,
                      color: selected ? AppColors.primary : AppColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                compact ? '按时间快速浏览' : '突出照片与营养信息',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayoutPreview extends StatelessWidget {
  const _LayoutPreview({required this.compact});

  final bool compact;

  Widget _line(double width) => FractionallySizedBox(
    widthFactor: width,
    alignment: Alignment.centerLeft,
    child: Container(
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.line,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    height: 100,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
    ),
    child: compact
        ? Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var index = 0; index < 2; index++)
                Row(
                  children: [
                    const Icon(
                      Icons.restaurant_outlined,
                      size: 24,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        children: [
                          _line(.8),
                          const SizedBox(height: 8),
                          _line(.5),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: ColoredBox(
                  color: AppColors.greenSoft,
                  child: Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _line(.7),
              const SizedBox(height: 6),
              _line(.4),
            ],
          ),
  );
}
