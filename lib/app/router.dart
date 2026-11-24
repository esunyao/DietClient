import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/ui_preview_config.dart';
import '../core/presentation/app_routes.dart';
import '../core/presentation/navigation_manager.dart';
import '../core/presentation/unsaved_form.dart';
import '../core/session/session_controller.dart';
import '../features/auth/presentation/screens/email_verified_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/verify_email_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/institution/presentation/screens/institution_menu_screen.dart';
import '../features/institution/presentation/screens/institution_sync_screen.dart';
import '../features/meal/presentation/screens/meal_correction_screen.dart';
import '../features/meal/presentation/screens/meal_detail_screen.dart';
import '../features/meal/presentation/screens/meal_history_screen.dart';
import '../features/meal/presentation/screens/native_meal_gallery_screen.dart';
import '../features/meal_plan/presentation/screens/meal_plan_screen.dart';
import '../features/meal_record/presentation/screens/recognition_screen.dart';
import '../features/profile/presentation/screens/ai_nutrition_consent_screen.dart';
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/profile/presentation/screens/health_record_form_screen.dart';
import '../features/profile/presentation/screens/health_records_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/report/presentation/screens/reports_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/trend/presentation/screens/trends_screen.dart';
import 'app_shell.dart';
import 'session_restore_screen.dart';

/// 会话恢复路由路径常量，兼容已有测试引用。
const sessionRestorePath = AppRoutes.sessionRestore;

/// 解析会话恢复完成后的站内跳转路径；仅允许站内目标，认证页与恢复页自身回退首页。
String sessionRestoredLocation(String? from) {
  final uri = from == null ? null : Uri.tryParse(from);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      uri.path == AppRoutes.sessionRestore ||
      AppRoutes.publicAuthRoutes.contains(uri.path)) {
    return AppRoutes.home;
  }
  return uri.toString();
}

/// 按登录状态对业务路径执行认证门控重定向；无需重定向时返回 `null`。
String? authenticationRedirect(
  String path, {
  required bool authenticated,
  bool uiPreview = false,
}) {
  final isPublic = AppRoutes.publicAuthRoutes.contains(path);
  if (uiPreview) return isPublic ? AppRoutes.home : null;
  if (!authenticated && !isPublic) return AppRoutes.login;
  if (authenticated && isPublic) return AppRoutes.home;
  return null;
}

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// 判断是否允许离开当前表单或采集路由；认证失效时优先放行以回到门控页。
Future<bool> _canLeaveRoute(
  Ref ref,
  bool uiPreview,
  BuildContext _,
  GoRouterState _,
) async {
  if (!uiPreview &&
      (!hasActiveSession(ref.read(sessionProvider)) ||
          ref.read(sessionStatusProvider) != SessionStatus.ready)) {
    return true;
  }
  return ref.read(routeLeaveRegistryProvider).confirm();
}

/// 统一处理会话恢复与认证门控重定向。
String? _resolveRedirect(
  Ref ref,
  bool uiPreview,
  BuildContext _,
  GoRouterState state,
) {
  final status = ref.read(sessionStatusProvider);
  final recovering =
      !kIsWeb &&
      !uiPreview &&
      (status == SessionStatus.booting ||
          status == SessionStatus.retryRequired);
  if (recovering) {
    return state.uri.path == AppRoutes.sessionRestore
        ? null
        : AppRoutes.sessionRestoreLocation(state.uri.toString());
  }
  if (state.uri.path == AppRoutes.sessionRestore) {
    return hasActiveSession(ref.read(sessionProvider))
        ? sessionRestoredLocation(
            state.uri.queryParameters[AppRoutes.fromQuery],
          )
        : AppRoutes.login;
  }
  return authenticationRedirect(
    state.uri.path,
    uiPreview: uiPreview,
    authenticated: hasActiveSession(ref.read(sessionProvider)),
  );
}

Widget _buildMealPhotosRoute(Ref ref, GoRouterState state) {
  if (!ref.read(nativeNutritionEnabledProvider)) {
    return const AppPage(
      title: '餐食照片',
      showBack: true,
      children: [InfoBanner(text: '此平台暂不支持查看真实餐食照片')],
    );
  }
  return NativeMealGalleryScreen(
    mealId: state.pathParameters[AppRoutes.mealIdParam]!,
    imageId: state.uri.queryParameters[AppRoutes.imageIdQuery],
  );
}

Widget _buildErrorPage(Ref ref, BuildContext context, bool uiPreview) =>
    AppPage(
      title: '没有找到这个页面',
      children: [
        InfoBanner(
          text: uiPreview ? '链接可能已失效，可以回到首页继续预览。' : '链接可能已失效，可以回到首页继续使用。',
        ),
        AppButton(
          label: '回到首页',
          onPressed: () => ref.read(navigationManagerProvider).goHome(context),
        ),
      ],
    );

/// 应用全局 GoRouter Provider，装配认证门控、恢复页、根相册路由与业务导航外壳。
final appRouterProvider = Provider<GoRouter>((ref) {
  final uiPreview = ref.watch(uiPreviewProvider);
  final refresh = _RouterRefresh();
  ref.listen(sessionProvider, (_, _) => refresh.refresh());
  ref.listen(sessionStatusProvider, (_, _) => refresh.refresh());

  Future<bool> canLeave(BuildContext context, GoRouterState state) =>
      _canLeaveRoute(ref, uiPreview, context, state);

  final router = GoRouter(
    initialLocation: uiPreview ? AppRoutes.home : AppRoutes.login,
    refreshListenable: refresh,
    redirect: (context, state) =>
        _resolveRedirect(ref, uiPreview, context, state),
    routes: [
      GoRoute(
        path: AppRoutes.sessionRestore,
        builder: (_, _) => const SessionRestoreScreen(),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, _) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: AppRoutes.emailVerified,
        builder: (_, _) => const EmailVerifiedScreen(),
      ),
      GoRoute(path: AppRoutes.root, redirect: (_, _) => AppRoutes.home),
      // 全屏相册挂载于根导航器之外，仍受统一认证与恢复重定向约束。
      GoRoute(
        path: AppRoutes.mealPhotosPattern,
        builder: (_, state) => _buildMealPhotosRoute(ref, state),
      ),
      ShellRoute(
        builder: (_, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: AppRoutes.capture,
            onExit: canLeave,
            builder: (_, _) => const RecognitionScreen(),
          ),
          GoRoute(
            path: AppRoutes.mealPlan,
            builder: (_, _) => const MealPlanScreen(),
          ),
          GoRoute(
            path: AppRoutes.trends,
            builder: (_, _) => const TrendsScreen(),
          ),
          GoRoute(
            path: AppRoutes.reports,
            builder: (_, _) => const ReportsScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, _) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (_, _) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.institutionMenu,
            builder: (_, _) => const InstitutionMenuScreen(),
          ),
          GoRoute(
            path: AppRoutes.institutionSync,
            builder: (_, _) => const InstitutionSyncScreen(),
          ),
          GoRoute(
            path: AppRoutes.manualMeal,
            onExit: canLeave,
            builder: (_, _) => const MealCorrectionScreen(),
          ),
          GoRoute(
            path: AppRoutes.mealHistory,
            builder: (_, _) => const MealHistoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.mealDetailPattern,
            builder: (_, state) => MealDetailScreen(
              mealId: state.pathParameters[AppRoutes.mealIdParam]!,
            ),
          ),
          GoRoute(
            path: AppRoutes.mealCorrectionPattern,
            onExit: canLeave,
            builder: (_, state) => MealCorrectionScreen(
              mealId: state.pathParameters[AppRoutes.mealIdParam]!,
            ),
          ),
          GoRoute(
            path: AppRoutes.editProfile,
            onExit: canLeave,
            builder: (_, _) => const EditProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.healthRecords,
            onExit: canLeave,
            builder: (_, _) => const HealthRecordsScreen(),
          ),
          GoRoute(
            path: AppRoutes.healthRecordFormPattern,
            onExit: canLeave,
            builder: (_, state) {
              final extra = state.extra;
              return HealthRecordFormScreen(
                kind: state.pathParameters[AppRoutes.healthKindParam]!,
                record: extra is Map<String, dynamic> ? extra : null,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.aiConsent,
            builder: (_, _) => const AiNutritionConsentScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, _) => _buildErrorPage(ref, context, uiPreview),
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
