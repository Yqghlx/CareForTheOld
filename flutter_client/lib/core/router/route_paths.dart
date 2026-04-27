/// 路由路径常量
/// 集中管理所有路由路径，便于维护和版本控制
class RoutePaths {
  RoutePaths._();

  // ==================== 认证 ====================
  static const String login = '/login';
  static const String register = '/register';

  // ==================== 老人端 ====================
  static const String elderHome = '/elder/home';
  static const String elderHealth = '/elder/health';
  static const String elderHealthTrend = '/elder/health/trend';
  static const String elderMedication = '/elder/medication';
  static const String elderFamily = '/elder/family';

  // ==================== 子女端 ====================
  static const String childHome = '/child/home';
  static const String childFamily = '/child/family';
  static const String childEmergency = '/child/emergency';
  static const String childElderHealthPattern = '/child/elder/:elderId/health';
  static const String childElderLocationPattern = '/child/elder/:elderId/location';
  static const String childElderHealthTrendPattern = '/child/elder/:elderId/health/trend';
  static String childElderHealth(String elderId) => '/child/elder/$elderId/health';
  static String childElderLocation(String elderId) => '/child/elder/$elderId/location';
  static String childElderHealthTrend(String elderId) => '/child/elder/$elderId/health/trend';

  // ==================== 共享 ====================
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String neighborCircle = '/neighbor-circle';
  static const String neighborHelp = '/neighbor-help';
  static const String neighborHelpRatePattern = '/neighbor-help/:id/rate';
  static String neighborHelpRate(String requestId) => '/neighbor-help/$requestId/rate';
  static const String trustRankingPattern = '/trust-ranking/:circleId';
  static String trustRanking(String circleId) => '/trust-ranking/$circleId';
}
