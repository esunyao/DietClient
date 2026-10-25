import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../demo/demo_store.dart';
import '../../../../core/presentation/account_identity.dart';
import '../widgets/institution_home_content.dart';
import '../widgets/personal_home_content.dart';
import '../../../../core/config/ui_preview_config.dart';
import 'native_home_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(nativeNutritionEnabledProvider)) {
      return const NativeHomeScreen();
    }
    final data = ref.watch(demoProvider);
    final institution = data.isInstitution;
    final date =
        '${demoDate.month}月${demoDate.day}日，星期${'一二三四五六日'[demoDate.weekday - 1]}';
    return LayoutBuilder(
      builder: (context, pageConstraints) => AppPage(
        demoLabel: '设计样例 · 演示数据',
        titleStyle: institution
            ? null
            : AppTypography.pageTitle.copyWith(fontSize: 24),
        mobileGutter: institution ? null : 20,
        title: institution ? '今天的膳食，一眼看清' : '今天，好好吃饭',
        eyebrow: institution ? null : date,
        subtitle: institution ? '$date。先看已记录的数据，再安排下一餐。' : null,
        trailing: institution
            ? Text(
                '${demoDate.month}月${demoDate.day}日 17:40',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              )
            : const AccountAvatar(size: 48),
        children: [
          if (institution)
            InstitutionHomeContent(data: data)
          else
            PersonalHomeContent(
              data: data,
              narrowPage:
                  pageConstraints.maxWidth < AppLayout.navigationBreakpoint,
            ),
        ],
      ),
    );
  }
}
