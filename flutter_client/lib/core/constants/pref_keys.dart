/// SharedPreferences 键名常量
/// 集中管理所有本地存储键名，防止拼写错误和便于全局替换
class PrefKeys {
  PrefKeys._();

  // ==================== 认证相关 ====================
  /// 用户角色
  static const userRole = 'userRole';

  /// 用户 ID
  static const userId = 'userId';

  // ==================== 家庭相关 ====================
  /// 家庭 ID
  static const familyId = 'familyId';

  /// 家庭名称
  static const familyName = 'familyName';

  // ==================== 设置相关 ====================
  /// 位置上报开关
  static const locationEnabled = 'location_enabled';

  /// 健康通知开关
  static const notifyHealth = 'notify_health';

  /// 用药通知开关
  static const notifyMedication = 'notify_medication';

  /// 邻里通知开关
  static const notifyNeighbor = 'notify_neighbor';
}

/// Hive 数据库 Box 名称常量
/// 集中管理所有 Hive box 名称，用于离线缓存和本地数据存储
class HiveBoxKeys {
  HiveBoxKeys._();

  /// 健康数据缓存 box
  static const healthCache = 'health_cache';

  /// 用药数据缓存 box
  static const medicationCache = 'medication_cache';

  /// 离线请求队列 box
  static const offlineQueue = 'offline_queue';
}
