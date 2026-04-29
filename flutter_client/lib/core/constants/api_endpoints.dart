/// API 端点路径常量
/// 集中管理所有接口路径，便于维护和版本控制
class ApiEndpoints {
  ApiEndpoints._();

  /// API 路径前缀，用于从 apiBaseUrl 中提取服务器基础地址
  static const apiPathPrefix = '/api/v1';

  // ==================== 认证 ====================
  static const authLogin = '/auth/login';
  static const authRegister = '/auth/register';
  static const authRefresh = '/auth/refresh';
  static const authLogout = '/auth/logout';

  // ==================== 用户 ====================
  static const userMe = '/user/me';
  static const userPassword = '/user/me/password';
  static const userAvatar = '/user/me/avatar';

  // ==================== 设备/FCM ====================
  static const deviceToken = '/device/token';

  // ==================== 家庭 ====================
  static const family = '/family';
  static const familyMe = '/family/me';
  static const familyJoin = '/family/join';
  static String familyMembers(String familyId) => '/family/$familyId/members';
  static String familyMember(String familyId, String userId) =>
      '/family/$familyId/members/$userId';
  static String familyRefreshCode(String familyId) =>
      '/family/$familyId/refresh-code';
  static String familyPendingMembers(String familyId) =>
      '/family/$familyId/pending-members';
  static String familyApprove(String familyId, String memberId) =>
      '/family/$familyId/members/$memberId/approve';
  static String familyReject(String familyId, String memberId) =>
      '/family/$familyId/members/$memberId/reject';

  // ==================== 健康 ====================
  static const health = '/health';
  static const healthMeStats = '/health/me/stats';
  static const healthMe = '/health/me';
  static const healthMeAnomaly = '/health/me/anomaly-detection';
  static String healthRecord(String id) => '/health/$id';
  static String healthFamilyMember(String familyId, String memberId) =>
      '/health/family/$familyId/member/$memberId';
  static String healthFamilyMemberStats(String familyId, String memberId) =>
      '/health/family/$familyId/member/$memberId/stats';
  static String healthFamilyMemberAnomaly(String familyId, String memberId) =>
      '/health/family/$familyId/member/$memberId/anomaly-detection';
  static String healthReport({String? familyId, String? elderId, int days = 30}) {
    if (familyId != null && elderId != null) {
      return '/health/family/$familyId/member/$elderId/report?days=$days';
    }
    return '/health/me/report?days=$days';
  }

  // ==================== 用药 ====================
  static const medicationPlansMe = '/medication/plans/me';
  static const medicationTodayPending = '/medication/today-pending';
  static const medicationLogs = '/medication/logs';
  static const medicationLogsMe = '/medication/logs/me';
  static String medicationLogsByElder(String elderId) =>
      '/medication/logs/elder/$elderId';
  static String medicationPlansByElder(String elderId) =>
      '/medication/plans/elder/$elderId';
  static const medicationPlans = '/medication/plans';
  static String medicationPlan(String planId) => '/medication/plans/$planId';

  // ==================== 位置 ====================
  static const location = '/location';
  static const locationMeLatest = '/location/me/latest';
  static const locationMeHistory = '/location/me/history';
  static String locationFamilyMember(String familyId, String memberId) =>
      '/location/family/$familyId/member/$memberId/latest';
  static String locationFamilyMemberHistory(String familyId, String memberId) =>
      '/location/family/$familyId/member/$memberId/history';

  // ==================== 围栏 ====================
  static const geoFence = '/geofence';
  static String geoFenceByElder(String elderId) => '/geofence/elder/$elderId';
  static String geoFenceById(String fenceId) => '/geofence/$fenceId';

  // ==================== 紧急呼叫 ====================
  static const emergency = '/emergency';
  static const emergencyUnread = '/emergency/unread';
  static const emergencyHistory = '/emergency/history';
  static String emergencyRespond(String callId) => '/emergency/$callId/respond';

  // ==================== 通知 ====================
  static const notificationMe = '/notification/me';
  static const notificationUnreadCount = '/notification/me/unread-count';
  static const notificationReadAll = '/notification/me/read-all';
  static String notificationRead(String notificationId) =>
      '/notification/$notificationId/read';

  // ==================== 邻里圈 ====================
  static const neighborCircle = '/neighborcircle';
  static const neighborCircleMe = '/neighborcircle/me';
  static const neighborCircleJoin = '/neighborcircle/join';
  static String neighborCircleById(String circleId) =>
      '/neighborcircle/$circleId';
  static String neighborCircleMembers(String circleId) =>
      '/neighborcircle/$circleId/members';
  static String neighborCircleLeave(String circleId) =>
      '/neighborcircle/$circleId/leave';
  static String neighborCircleRefreshCode(String circleId) =>
      '/neighborcircle/$circleId/refresh-code';
  static String neighborCircleNearbyMembers(String circleId) =>
      '/neighborcircle/$circleId/nearby-members';
  static const neighborCircleSearchNearby = '/neighborcircle/nearby';

  // ==================== 邻里互助 ====================
  static const neighborHelpPending = '/neighborhelp/pending';
  static const neighborHelpHistory = '/neighborhelp/history';
  static String neighborHelpById(String requestId) =>
      '/neighborhelp/$requestId';
  static String neighborHelpAccept(String requestId) =>
      '/neighborhelp/$requestId/accept';
  static String neighborHelpCancel(String requestId) =>
      '/neighborhelp/$requestId/cancel';
  static String neighborHelpRate(String requestId) =>
      '/neighborhelp/$requestId/rate';

  // ==================== 自动救援 ====================
  static String autoRescueRespond(String recordId) =>
      '/auto-rescue/$recordId/respond';
  static const autoRescueHistory = '/auto-rescue/history';

  // ==================== 信任评分 ====================
  static String trustScoreMe(String circleId) =>
      '/neighbor-circles/$circleId/trust/me';
  static String trustScoreRanking(String circleId) =>
      '/neighbor-circles/$circleId/trust/ranking';
}
