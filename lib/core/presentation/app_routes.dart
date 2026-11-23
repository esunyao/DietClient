/// 集中定义应用路径及动态路径构造；路由注册和页面选择由应用层负责。
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
  // 动态标识按路径段编码，相册的可选图片标识按查询参数编码。
  static String mealDetail(String id) => '/meals/${Uri.encodeComponent(id)}';
  static String mealPhotos(String id, {String? imageId}) =>
      '${mealDetail(id)}/photos'
      '${imageId == null ? '' : '?imageId=${Uri.encodeQueryComponent(imageId)}'}';
  static String mealCorrection(String id) => '${mealDetail(id)}/correction';
  static String healthRecordForm(String kind) =>
      '$healthRecords/${Uri.encodeComponent(kind)}';
}
