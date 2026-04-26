/// API 端点路径常量
/// 集中管理所有接口路径，便于维护和版本控制
class ApiEndpoints {
  ApiEndpoints._();

  // ==================== 认证 ====================
  static const authLogin = '/auth/login';
  static const authRegister = '/auth/register';

  // ==================== 用户 ====================
  static const userMe = '/user/me';
  static const userPassword = '/user/me/password';

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

  // ==================== 用药 ====================
  static const medicationPlansMe = '/medication/plans/me';
  static const medicationTodayPending = '/medication/today-pending';
  static const medicationLogs = '/medication/logs';
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

  // ==================== 邻里互助 ====================
  static const neighborHelpPending = '/neighborhelp/pending';
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

  // ==================== 信任评分 ====================
  static String trustScoreMe(String circleId) =>
      '/neighbor-circles/$circleId/trust/me';
}
