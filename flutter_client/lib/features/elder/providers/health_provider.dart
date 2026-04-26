import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/extensions/api_error_extension.dart';
import '../../../core/services/health_cache_service.dart';
import '../../../core/theme/app_theme.dart';
import '../services/health_service.dart';
import '../../../shared/models/health_record.dart';
import '../../../shared/models/health_stats.dart';

/// 健康服务 Provider
final healthServiceProvider = Provider<HealthService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  return HealthService(dio);
});

/// 健康缓存服务 Provider
final healthCacheServiceProvider = Provider<HealthCacheService>((ref) {
  return HealthCacheService();
});

/// 健康记录列表状态
class HealthRecordsState {
  final List<HealthRecord> records;
  final bool isLoading;
  final String? error;
  final HealthType? selectedFilter;
  final bool isFromCache; // 标记数据来源是否为本地缓存

  const HealthRecordsState({
    this.records = const [],
    this.isLoading = false,
    this.error,
    this.selectedFilter,
    this.isFromCache = false,
  });

  HealthRecordsState copyWith({
    List<HealthRecord>? records,
    bool? isLoading,
    String? error,
    HealthType? selectedFilter,
    bool? isFromCache,
    bool clearError = false,
  }) {
    return HealthRecordsState(
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedFilter: selectedFilter ?? this.selectedFilter,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }
}

/// 健康记录列表 Notifier
class HealthRecordsNotifier extends StateNotifier<HealthRecordsState> {
  final HealthService _healthService;
  final HealthCacheService _cacheService;

  HealthRecordsNotifier(this._healthService, this._cacheService)
      : super(const HealthRecordsState());

  /// 加载健康记录（网络优先，失败降级到缓存）
  Future<void> loadRecords({HealthType? type}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final records = await _healthService.getMyRecords(type: type);
      // 网络成功：更新缓存
      if (type == null) {
        await _cacheService.cacheMyRecords(records);
      }
      state = state.copyWith(
        records: records,
        isLoading: false,
        selectedFilter: type,
        isFromCache: false,
      );
    } on DioException catch (e) {
      // 网络失败：降级读取缓存
      final cached = type != null
          ? _cacheService.getCachedRecordsByType(type)
          : _cacheService.getCachedMyRecords();
      if (cached.isNotEmpty) {
        state = state.copyWith(
          records: cached,
          isLoading: false,
          selectedFilter: type,
          isFromCache: true,
        );
      } else {
        state = state.copyWith(isLoading: false, error: e.toDisplayMessage());
      }
    } catch (e) {
      final cached = type != null
          ? _cacheService.getCachedRecordsByType(type)
          : _cacheService.getCachedMyRecords();
      if (cached.isNotEmpty) {
        state = state.copyWith(
          records: cached,
          isLoading: false,
          selectedFilter: type,
          isFromCache: true,
        );
      } else {
        state = state.copyWith(isLoading: false, error: AppTheme.msgOperationFailed);
      }
    }
  }

  /// 创建新记录
  Future<bool> createRecord({
    required HealthType type,
    int? systolic,
    int? diastolic,
    double? bloodSugar,
    int? heartRate,
    double? temperature,
    String? note,
  }) async {
    try {
      final newRecord = await _healthService.createRecord(
        type: type,
        systolic: systolic,
        diastolic: diastolic,
        bloodSugar: bloodSugar,
        heartRate: heartRate,
        temperature: temperature,
        note: note,
      );
      // 将新记录插入列表头部
      state = state.copyWith(records: [newRecord, ...state.records]);
      // 更新缓存
      await _cacheService.cacheMyRecords(state.records);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: e.toDisplayMessage());
      return false;
    } catch (e) {
      state = state.copyWith(error: AppTheme.msgOperationFailed);
      return false;
    }
  }

  /// 删除记录
  Future<bool> deleteRecord(String id) async {
    try {
      await _healthService.deleteRecord(id);
      state = state.copyWith(
        records: state.records.where((r) => r.id != id).toList(),
      );
      await _cacheService.cacheMyRecords(state.records);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: e.toDisplayMessage());
      return false;
    } catch (e) {
      state = state.copyWith(error: AppTheme.msgOperationFailed);
      return false;
    }
  }

  /// 切换筛选类型
  void filterByType(HealthType? type) {
    loadRecords(type: type);
  }
}

/// 健康记录列表 Provider
final healthRecordsProvider =
    StateNotifierProvider<HealthRecordsNotifier, HealthRecordsState>((ref) {
  final service = ref.watch(healthServiceProvider);
  final cache = ref.watch(healthCacheServiceProvider);
  return HealthRecordsNotifier(service, cache);
});

/// 健康统计数据 Provider（自动获取）
final healthStatsProvider = FutureProvider<List<HealthStats>>((ref) async {
  final service = ref.watch(healthServiceProvider);
  return service.getMyStats();
});
