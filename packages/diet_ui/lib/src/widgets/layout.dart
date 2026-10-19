import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

class PlateIllustration extends StatelessWidget {
  const PlateIllustration({super.key, this.size = 48});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '餐盘示意',
    child: SvgPicture.asset(
      'assets/illustrations/plate.svg',
      package: 'diet_ui',
      width: size,
      height: size,
    ),
  );
}

class AvatarIllustration extends StatelessWidget {
  const AvatarIllustration({super.key, this.size = 48});
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/illustrations/avatar.svg',
    package: 'diet_ui',
    width: size,
    height: size,
    semanticsLabel: '示例头像',
  );
}

class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      minLeadingWidth: 36,
      leading: leading,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : const Icon(Icons.chevron_right, color: AppColors.muted)),
      onTap: onTap,
    ),
  );
}

class AdaptiveColumns extends StatelessWidget {
  const AdaptiveColumns({super.key, required this.main, this.aside = const []});
  final List<Widget> main;
  final List<Widget> aside;
  Widget _column(List<Widget> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < items.length; i++) ...[
        items[i],
        if (i < items.length - 1) const SizedBox(height: 16),
      ],
    ],
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (MediaQuery.sizeOf(context).width < 1024 || aside.isEmpty)
        return _column([...main, ...aside]);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: _column(main)),
          const SizedBox(width: 24),
          Expanded(child: _column(aside)),
        ],
      );
    },
  );
}
