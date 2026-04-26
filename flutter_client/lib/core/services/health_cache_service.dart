import 'dart:convert';
import 'package:hive/hive.dart';
import '../../shared/models/health_record.dart';
import '../../shared/models/medication_plan.dart';

/// 健康数据本地缓存服务
///
/// 使用 Hive 缓存健康记录和用药计划，断网时仍可查看历史数据。
/// 每次网络请求成功后自动更新缓存，离线时自动降级读取缓存。
class HealthCacheService {
  static const _healthBox = 'health_cache';
  static const _medicationBox = 'medication_cache';
  static const _healthKey = 'my_records';
  static const _medicationKey = 'my_plans';
  static const _maxCacheRecords = 100;

  Box<String>? _hBox;
  Box<String>? _mBox;

  /// 初始化 Hive Boxes
  Future<void> init() async {
    _hBox = await Hive.openBox<String>(_healthBox);
    _mBox = await Hive.openBox<String>(_medicationBox);
  }

  // ==================== 健康记录缓存 ====================

  /// 缓存老人自己的健康记录
  Future<void> cacheMyRecords(List<HealthRecord> records) async {
    if (_hBox == null) return;
    // 只保留最近 N 条
    final trimmed = records.length > _maxCacheRecords
        ? records.sublist(records.length - _maxCacheRecords)
        : records;
    final jsonList = trimmed.map((r) => r.toJson()).toList();
    await _hBox!.put(_healthKey, jsonEncode(jsonList));
  }

  /// 读取缓存的健康记录
  List<HealthRecord> getCachedMyRecords() {
    if (_hBox == null) return [];
    final raw = _hBox!.get(_healthKey);
    if (raw == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(raw);
      return jsonList.map((j) => HealthRecord.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// 按类型筛选缓存的记录
  List<HealthRecord> getCachedRecordsByType(HealthType type) {
    return getCachedMyRecords().where((r) => r.type == type).toList();
  }

  // ==================== 用药计划缓存 ====================

  /// 缓存用药计划
  Future<void> cacheMedicationPlans(List<MedicationPlan> plans) async {
    if (_mBox == null) return;
    final jsonList = plans.map((p) => p.toJson()).toList();
    await _mBox!.put(_medicationKey, jsonEncode(jsonList));
  }

  /// 读取缓存的用药计划
  List<MedicationPlan> getCachedMedicationPlans() {
    if (_mBox == null) return [];
    final raw = _mBox!.get(_medicationKey);
    if (raw == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(raw);
      return jsonList.map((j) => MedicationPlan.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}

/// 缓存状态标记，用于 UI 区分"网络数据"和"缓存数据"
class CachedData<T> {
  final T data;
  final bool isFromCache;
  final DateTime? cachedAt;

  const CachedData({
    required this.data,
    this.isFromCache = false,
    this.cachedAt,
  });
}
