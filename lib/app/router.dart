import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/ui_preview_config.dart';
import '../core/presentation/app_routes.dart';
import '../core/presentation/unsaved_form.dart';
import '../core/session/session_controller.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/meal_record/presentation/screens/recognition_screen.dart';
import '../features/meal/presentation/screens/meal_history_screen.dart';
import '../features/meal/presentation/screens/meal_detail_screen.dart';
import '../features/meal/presentation/screens/native_meal_gallery_screen.dart';
import '../features/meal/presentation/screens/meal_correction_screen.dart';
import '../features/meal_plan/presentation/screens/meal_plan_screen.dart';
import '../features/institution/presentation/screens/institution_menu_screen.dart';
import '../features/institution/presentation/screens/institution_sync_screen.dart';
import '../features/trend/presentation/screens/trends_screen.dart';
import '../features/report/presentation/screens/reports_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/verify_email_screen.dart';
import '../features/auth/presentation/screens/email_verified_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/profile/presentation/screens/health_records_screen.dart';
import '../features/profile/presentation/screens/health_record_form_screen.dart';
import '../features/profile/presentation/screens/ai_nutrition_consent_screen.dart';
import 'app_shell.dart';
import 'session_restore_screen.dart';

const sessionRestorePath = '/session/restore';

/// 只允许站内目标；恢复页自身和认证页在成功后回首页。
String sessionRestoredLocation(String? from) {
  final uri = from == null ? null : Uri.tryParse(from);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      {
        sessionRestorePath,
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.verifyEmail,
        AppRoutes.emailVerified,
      }.contains(uri.path)) {
    return AppRoutes.home;
  }
  return uri.toString();
}

String? authenticationRedirect(
  String path, {
  required bool authenticated,
  bool uiPreview = false,
}) {
  const public = {
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.verifyEmail,
    AppRoutes.emailVerified,
  };
  if (uiPreview) return public.contains(path) ? AppRoutes.home : null;
  if (!authenticated && !public.contains(path)) return AppRoutes.login;
  if (authenticated && public.contains(path)) return AppRoutes.home;
  return null;
}

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final uiPreview = ref.watch(uiPreviewProvider);
  final refresh = _RouterRefresh();
  ref.listen(sessionProvider, (_, next) => refresh.refresh());
  ref.listen(sessionStatusProvider, (_, next) => refresh.refresh());
  Future<bool> canLeave(BuildContext context, GoRouterState state) async {
    // 会话失效必须立即离开业务页，表单保护不能阻止认证门控。
    if (!uiPreview &&
        (!hasActiveSession(ref.read(sessionProvider)) ||
            ref.read(sessionStatusProvider) != SessionStatus.ready)) {
      return true;
    }
    return ref.read(routeLeaveRegistryProvider).confirm();
  }

  final router = GoRouter(
    initialLocation: uiPreview ? AppRoutes.home : AppRoutes.login,
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(sessionStatusProvider);
      final recovering =
          !kIsWeb &&
          !uiPreview &&
          (status == SessionStatus.booting ||
              status == SessionStatus.retryRequired);
      if (recovering) {
        return state.uri.path == sessionRestorePath
            ? null
            : '$sessionRestorePath?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (state.uri.path == sessionRestorePath) {
        return hasActiveSession(ref.read(sessionProvider))
            ? sessionRestoredLocation(state.uri.queryParameters['from'])
            : AppRoutes.login;
      }
      return authenticationRedirect(
        state.uri.path,
        uiPreview: uiPreview,
        authenticated: hasActiveSession(ref.read(sessionProvider)),
      );
    },
    routes: [
      GoRoute(
        path: sessionRestorePath,
        builder: (context, state) => const SessionRestoreScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: AppRoutes.emailVerified,
        builder: (context, state) => const EmailVerifiedScreen(),
      ),
      GoRoute(path: '/', redirect: (context, state) => AppRoutes.home),
      // 相册在根导航器显示；统一 redirect 仍负责认证和恢复。
      GoRoute(
        path: '/meals/:id/photos',
        builder: (context, state) {
          if (!ref.read(nativeNutritionEnabledProvider)) {
            return const AppPage(
              title: '餐食照片',
              showBack: true,
              children: [InfoBanner(text: '此平台暂不支持查看真实餐食照片')],
            );
          }
          return NativeMealGalleryScreen(
            mealId: state.pathParameters['id']!,
            imageId: state.uri.queryParameters['imageId'],
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.capture,
            onExit: canLeave,
            builder: (context, state) => const RecognitionScreen(),
          ),
          GoRoute(
            path: AppRoutes.mealPlan,
            builder: (context, state) => const MealPlanScreen(),
          ),
          GoRoute(
            path: AppRoutes.trends,
            builder: (context, state) => const TrendsScreen(),
          ),
          GoRoute(
            path: AppRoutes.reports,
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.institutionMenu,
            builder: (context, state) => const InstitutionMenuScreen(),
          ),
          GoRoute(
            path: AppRoutes.institutionSync,
            builder: (context, state) => const InstitutionSyncScreen(),
          ),
          GoRoute(
            path: AppRoutes.manualMeal,
            onExit: canLeave,
            builder: (context, state) => const MealCorrectionScreen(),
          ),
          GoRoute(
            path: AppRoutes.mealHistory,
            builder: (context, state) => const MealHistoryScreen(),
          ),
          GoRoute(
            path: '/meals/:id',
            builder: (context, state) =>
                MealDetailScreen(mealId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/meals/:id/correction',
            onExit: canLeave,
            builder: (context, state) =>
                MealCorrectionScreen(mealId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: AppRoutes.editProfile,
            onExit: canLeave,
            builder: (context, state) => const EditProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.healthRecords,
            onExit: canLeave,
            builder: (context, state) => const HealthRecordsScreen(),
          ),
          GoRoute(
            path: '/profile/health-records/:kind',
            onExit: canLeave,
            builder: (context, state) =>
                HealthRecordFormScreen(kind: state.pathParameters['kind']!),
          ),
          GoRoute(
            path: AppRoutes.aiConsent,
            builder: (context, state) => const AiNutritionConsentScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => AppPage(
      title: '没有找到这个页面',
      children: [
        InfoBanner(
          text: uiPreview ? '链接可能已失效，可以回到首页继续预览。' : '链接可能已失效，可以回到首页继续使用。',
        ),
        AppButton(label: '回到首页', onPressed: () => context.go(AppRoutes.home)),
      ],
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
