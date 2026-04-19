import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../services/medication_service.dart';
import '../../../shared/models/medication_plan.dart';
import '../../../shared/models/medication_log.dart';

/// 用药服务 Provider
final medicationServiceProvider = Provider<MedicationService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  return MedicationService(dio);
});

/// 用药状态
class MedicationState {
  final List<MedicationPlan> plans;
  final List<MedicationLog> todayPending;
  final bool isLoading;
  final String? error;

  const MedicationState({
    this.plans = const [],
    this.todayPending = const [],
    this.isLoading = false,
    this.error,
  });

  MedicationState copyWith({
    List<MedicationPlan>? plans,
    List<MedicationLog>? todayPending,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return MedicationState(
      plans: plans ?? this.plans,
      todayPending: todayPending ?? this.todayPending,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// 待服用数量
  int get pendingCount => todayPending.where((l) => l.isPending).length;

  /// 已服数量
  int get takenCount => todayPending.where((l) => l.status == MedicationStatus.taken).length;

  /// 跳过/漏服数量
  int get skippedCount => todayPending.where((l) => l.status == MedicationStatus.skipped).length;
}

/// 用药状态 Notifier
class MedicationNotifier extends StateNotifier<MedicationState> {
  final MedicationService _service;

  /// 正在提交的用药记录 key 集合（planId_scheduledAt），防止重复提交
  final Set<String> _submittingKeys = {};

  MedicationNotifier(this._service) : super(const MedicationState());

  /// 生成防重复提交的 key
  String _logKey(MedicationLog log) => '${log.planId}_${log.scheduledAt.toIso8601String()}';

  /// 加载所有用药数据（计划 + 今日待服）
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _service.getMyPlans(),
        _service.getTodayPending(),
      ]);
      state = state.copyWith(
        plans: results[0] as List<MedicationPlan>,
        todayPending: results[1] as List<MedicationLog>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 替换列表中匹配 planId + scheduledAt 的记录
  List<MedicationLog> _replaceByPlanAndTime(
    List<MedicationLog> list,
    MedicationLog updated,
  ) {
    return list.map((l) {
      // today-pending 返回的项没有 id（后端 Guid.Empty），
      // 因此用 planId + scheduledAt 匹配
      final samePlan = l.planId == updated.planId;
      final sameTime =
          (l.scheduledAt.difference(updated.scheduledAt).inMinutes).abs() <= 1;
      return (samePlan && sameTime) ? updated : l;
    }).toList();
  }

  /// 标记已服用（带防重复提交保护）
  Future<bool> markAsTaken(MedicationLog log) async {
    final key = _logKey(log);
    if (_submittingKeys.contains(key)) return false;
    _submittingKeys.add(key);
    try {
      final updated = await _service.recordLog(
        planId: log.planId,
        status: MedicationStatus.taken,
        scheduledAt: log.scheduledAt,
      );
      final newList = _replaceByPlanAndTime(state.todayPending, updated);
      state = state.copyWith(todayPending: newList);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    } finally {
      _submittingKeys.remove(key);
    }
  }

  /// 标记跳过（带防重复提交保护）
  Future<bool> markAsSkipped(MedicationLog log) async {
    final key = _logKey(log);
    if (_submittingKeys.contains(key)) return false;
    _submittingKeys.add(key);
    try {
      final updated = await _service.recordLog(
        planId: log.planId,
        status: MedicationStatus.skipped,
        scheduledAt: log.scheduledAt,
      );
      final newList = _replaceByPlanAndTime(state.todayPending, updated);
      state = state.copyWith(todayPending: newList);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    } finally {
      _submittingKeys.remove(key);
    }
  }
}

/// 用药状态 Provider
final medicationProvider =
    StateNotifierProvider<MedicationNotifier, MedicationState>((ref) {
  final service = ref.watch(medicationServiceProvider);
  return MedicationNotifier(service);
});
