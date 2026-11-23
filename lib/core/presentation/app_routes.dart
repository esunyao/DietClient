/// @brief 应用路由路径常量与动态路径构造工具。
/// @details 集中定义路径协议，路由注册和页面选择由应用层负责。
abstract final class AppRoutes {
  static const home = '/home';
  static const capture = '/capture';
  static const mealPlan = '/meal-plan';
  static const trends = '/trends';
  static const reports = '/reports';
  static const profile = '/profile';
  static const settings = '/settings';
  static const manualMeal = '/meals/new';
  static const institutionMenu = '/institution/menu';
  static const institutionSync = '/institution/sync';
  static const mealHistory = '/meals';
  static const login = '/login';
  static const register = '/register';
  static const verifyEmail = '/verify-email';
  static const emailVerified = '/email-verified';
  static const editProfile = '/profile/edit';
  static const healthRecords = '/profile/health-records';
  static const aiConsent = '/profile/ai-consent';

  /// @brief 构造单餐详情路由路径。
  /// @details 动态标识按路径段编码；相册的可选图片标识按查询参数编码。
  /// @param id 餐食标识。
  /// @return 编码后的单餐详情路径。
  static String mealDetail(String id) => '/meals/${Uri.encodeComponent(id)}';
  static String mealPhotos(String id, {String? imageId}) =>
      '${mealDetail(id)}/photos'
      '${imageId == null ? '' : '?imageId=${Uri.encodeQueryComponent(imageId)}'}';
  static String mealCorrection(String id) => '${mealDetail(id)}/correction';
  static String healthRecordForm(String kind) =>
      '$healthRecords/${Uri.encodeComponent(kind)}';
}
