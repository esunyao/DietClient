import 'package:diet_ui/diet_ui.dart';
import 'package:go_router/go_router.dart';

import '../core/presentation/app_routes.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/meal_record/presentation/screens/recognition_screen.dart';
import '../features/meal/presentation/screens/meal_history_screen.dart';
import '../features/meal/presentation/screens/meal_detail_screen.dart';
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

final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(path: '/', redirect: (context, state) => AppRoutes.home),
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
          builder: (context, state) =>
              MealCorrectionScreen(mealId: state.pathParameters['id']!),
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
        GoRoute(
          path: AppRoutes.editProfile,
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          path: AppRoutes.healthRecords,
          builder: (context, state) => const HealthRecordsScreen(),
        ),
        GoRoute(
          path: '/profile/health-records/:kind',
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
      const InfoBanner(text: '链接可能已失效，可以回到首页继续演示。'),
      AppButton(label: '回到首页', onPressed: () => context.go(AppRoutes.home)),
    ],
  ),
);
