import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';
import 'unsaved_form.dart';

/// 全局导航管理器 Provider，统一收拢所有页面路由跳转、离开保护门控与帧后安全返回逻辑。
final navigationManagerProvider = Provider<AppNavigationManager>(
  AppNavigationManager.new,
);

/// 统一导航管理器，页面层通过此类执行路由切换与压栈，避免散落调用 `GoRouter` 或 `Navigator.push`。
class AppNavigationManager {
  AppNavigationManager(this._ref);

  final Ref _ref;

  /// 跳转到应用首页。
  void goHome(BuildContext context) => context.go(AppRoutes.home);

  /// 根据主导航索引切换到对应主入口页。
  void goTab(BuildContext context, int index) =>
      context.go(AppRoutes.primaryTabs[index]);

  /// 跳转到登录页。
  void goLogin(BuildContext context) => context.go(AppRoutes.login);

  /// 跳转到“我的”主入口页。
  void goProfile(BuildContext context) => context.go(AppRoutes.profile);

  /// 直接切换到饮食历史列表页。
  void goMealHistory(BuildContext context) => context.go(AppRoutes.mealHistory);

  /// 打开拍照记录采集页。
  void openCapture(BuildContext context) => context.push(AppRoutes.capture);

  /// 打开手工记录页。
  void openManualMeal(BuildContext context) =>
      context.push(AppRoutes.manualMeal);

  /// 压栈打开饮食历史页。
  void openMealHistory(BuildContext context) =>
      context.push(AppRoutes.mealHistory);

  /// 打开指定餐食详情页。
  void openMealDetail(BuildContext context, String mealId) =>
      context.push(AppRoutes.mealDetail(mealId));

  /// 打开指定餐食核对与修正页。
  void openMealCorrection(BuildContext context, String mealId) =>
      context.push(AppRoutes.mealCorrection(mealId));

  /// 打开全屏餐食相册页，可选定位初始图片 [imageId]。
  void openMealPhotos(BuildContext context, String mealId, {String? imageId}) =>
      context.push(AppRoutes.mealPhotos(mealId, imageId: imageId));

  /// 打开编辑基础资料页。
  void openEditProfile(BuildContext context) =>
      context.push(AppRoutes.editProfile);

  /// 打开健康档案总览页。
  void openHealthRecords(BuildContext context) =>
      context.push(AppRoutes.healthRecords);

  /// 打开指定健康类别表单页；[record] 非空时通过路由 `extra` 透传待编辑记录。
  void openHealthRecordForm(
    BuildContext context,
    String kind, {
    Map<String, dynamic>? record,
  }) => context.push(AppRoutes.healthRecordForm(kind), extra: record);

  /// 打开 AI 营养分析授权页。
  void openAiConsent(BuildContext context) => context.push(AppRoutes.aiConsent);

  /// 打开营养报告页。
  void openReports(BuildContext context) => context.push(AppRoutes.reports);

  /// 打开营养趋势页。
  void openTrends(BuildContext context) => context.push(AppRoutes.trends);

  /// 打开机构菜单页。
  void openInstitutionMenu(BuildContext context) =>
      context.push(AppRoutes.institutionMenu);

  /// 打开机构同步页。
  void openInstitutionSync(BuildContext context) =>
      context.push(AppRoutes.institutionSync);

  /// 打开注册演示/真实流程页。
  void openRegister(BuildContext context) => context.push(AppRoutes.register);

  /// 打开邮箱验证说明页。
  void openVerifyEmail(BuildContext context) =>
      context.push(AppRoutes.verifyEmail);

  /// 打开邮箱已验证回执页。
  void openEmailVerified(BuildContext context) =>
      context.push(AppRoutes.emailVerified);

  /// 当没有表单处于保存阻塞状态时打开应用设置页。
  void openSettingsGuarded(BuildContext context) {
    if (_ref.read(routeLeaveRegistryProvider).busy) return;
    context.push(AppRoutes.settings);
  }

  /// 当没有表单处于保存阻塞状态时打开机构菜单页。
  void openInstitutionMenuGuarded(BuildContext context) {
    if (_ref.read(routeLeaveRegistryProvider).busy) return;
    context.push(AppRoutes.institutionMenu);
  }

  /// 用指定餐食详情页替换当前路由（用于新建/提交采集后跳转）。
  void replaceWithMealDetail(BuildContext context, String mealId) =>
      context.pushReplacement(AppRoutes.mealDetail(mealId));

  /// 返回上一页；无返回栈时转往 [fallbackLocation]。
  void returnOrFallback(BuildContext context, String fallbackLocation) =>
      returnOrGo(context, fallbackLocation);

  /// 判断当前上下文是否存在可弹出路由；未接入路由容器时视为可弹出。
  bool canPop(BuildContext context) =>
      GoRouter.maybeOf(context)?.canPop() ?? true;

  /// 关闭当前栈顶页面并可选回传结果，优先使用路由器出栈。
  void pop<T extends Object?>(BuildContext context, [T? result]) {
    if (GoRouter.maybeOf(context) != null) {
      context.pop(result);
    } else {
      Navigator.of(context).pop(result);
    }
  }

  /// 请求执行路由系统返回检查，保留未保存表单离开拦截。
  Future<bool> maybePop(BuildContext context) =>
      Navigator.of(context).maybePop();

  /// 在下一帧执行安全返回；仅在页面存活、[isValid] 通过且仍为当前路由时生效。
  void scheduleSafeReturn(
    BuildContext context, {
    required String fallbackLocation,
    bool Function()? isValid,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (isValid != null && !isValid()) return;
      if (ModalRoute.of(context)?.isCurrent == false) return;
      returnOrGo(context, fallbackLocation);
    });
  }

  /// 在下一帧用目标路径替换当前页；仅在页面存活、[isValid] 通过且仍为当前路由时生效。
  void scheduleSafeReplace(
    BuildContext context,
    String location, {
    bool Function()? isValid,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (isValid != null && !isValid()) return;
      if (ModalRoute.of(context)?.isCurrent == false) return;
      context.pushReplacement(location);
    });
  }
}
