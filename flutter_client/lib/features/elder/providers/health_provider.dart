import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../services/health_service.dart';
import '../../../shared/models/health_record.dart';
import '../../../shared/models/health_stats.dart';

/// 健康服务 Provider
final healthServiceProvider = Provider<HealthService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  return HealthService(dio);
});

/// 健康记录列表状态
class HealthRecordsState {
  final List<HealthRecord> records;
  final bool isLoading;
  final String? error;
  final HealthType? selectedFilter;

  const HealthRecordsState({
    this.records = const [],
    this.isLoading = false,
    this.error,
    this.selectedFilter,
  });

  HealthRecordsState copyWith({
    List<HealthRecord>? records,
    bool? isLoading,
    String? error,
    HealthType? selectedFilter,
    bool clearError = false,
  }) {
    return HealthRecordsState(
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedFilter: selectedFilter ?? this.selectedFilter,
    );
  }
}

/// 健康记录列表 Notifier
class HealthRecordsNotifier extends StateNotifier<HealthRecordsState> {
  final HealthService _healthService;

  HealthRecordsNotifier(this._healthService)
      : super(const HealthRecordsState());

  /// 加载健康记录
  Future<void> loadRecords({HealthType? type}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final records = await _healthService.getMyRecords(type: type);
      state = state.copyWith(
        records: records,
        isLoading: false,
        selectedFilter: type,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
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
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
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
  return HealthRecordsNotifier(service);
});

/// 健康统计数据 Provider（自动获取）
final healthStatsProvider = FutureProvider<List<HealthStats>>((ref) async {
  final service = ref.watch(healthServiceProvider);
  return service.getMyStats();
});
