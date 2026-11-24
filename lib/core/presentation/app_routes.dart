/// 应用路由路径常量、动态模板、参数键及路由分组规则的唯一来源。
abstract final class AppRoutes {
  static const root = '/';
  static const sessionRestore = '/session/restore';
  static const institutionPrefix = '/institution';

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

  static const mealIdParam = 'id';
  static const imageIdQuery = 'imageId';
  static const healthKindParam = 'kind';
  static const fromQuery = 'from';

  static const mealDetailPattern = '/meals/:$mealIdParam';
  static const mealPhotosPattern = '/meals/:$mealIdParam/photos';
  static const mealCorrectionPattern = '/meals/:$mealIdParam/correction';
  static const healthRecordFormPattern = '$healthRecords/:$healthKindParam';

  /// 底部与顶部主导航的四个有序主入口路径。
  static const List<String> primaryTabs = [home, mealPlan, trends, profile];

  /// 未登录时可访问的公开认证页面路径集合。
  static const Set<String> publicAuthRoutes = {
    login,
    register,
    verifyEmail,
    emailVerified,
  };

  /// 判断 [location] 是否为四个主导航入口之一。
  static bool isPrimaryTab(String location) => primaryTabs.contains(location);

  /// 将当前路由路径映射为主导航索引（0 首页、1 配餐/机构、2 趋势/报告、3 我的/设置）。
  static int tabIndexFor(String location) {
    if (location.startsWith(institutionPrefix) ||
        location.startsWith(mealPlan)) {
      return 1;
    }
    if (location.startsWith(trends) || location.startsWith(reports)) {
      return 2;
    }
    if (location.startsWith(profile) || location == settings) {
      return 3;
    }
    return 0;
  }

  /// 构造携带原始来源站内路径的会话恢复跳转地址。
  static String sessionRestoreLocation(String from) =>
      '$sessionRestore?$fromQuery=${Uri.encodeComponent(from)}';

  /// 构造单餐详情路由路径。
  static String mealDetail(String id) => '/meals/${Uri.encodeComponent(id)}';

  /// 构造全屏餐食相册路由路径；可选传入初始定位的 [imageId]。
  static String mealPhotos(String id, {String? imageId}) =>
      '${mealDetail(id)}/photos'
      '${imageId == null ? '' : '?$imageIdQuery=${Uri.encodeQueryComponent(imageId)}'}';

  /// 构造单餐核对与修正路由路径。
  static String mealCorrection(String id) => '${mealDetail(id)}/correction';

  /// 构造指定健康记录类别的新增/编辑路由路径。
  static String healthRecordForm(String kind) =>
      '$healthRecords/${Uri.encodeComponent(kind)}';
}
