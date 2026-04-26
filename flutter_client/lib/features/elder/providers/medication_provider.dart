import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/offline_queue_service.dart';
import '../../../core/services/connectivity_service.dart';
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

  /// 正在提交中的用药记录 key 集合，用于 UI 显示 loading 状态
  final Set<String> submittingKeys;

  const MedicationState({
    this.plans = const [],
    this.todayPending = const [],
    this.isLoading = false,
    this.error,
    this.submittingKeys = const {},
  });

  MedicationState copyWith({
    List<MedicationPlan>? plans,
    List<MedicationLog>? todayPending,
    bool? isLoading,
    String? error,
    bool clearError = false,
    Set<String>? submittingKeys,
  }) {
    return MedicationState(
      plans: plans ?? this.plans,
      todayPending: todayPending ?? this.todayPending,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      submittingKeys: submittingKeys ?? this.submittingKeys,
    );
  }

  /// 待服用数量
  int get pendingCount => todayPending.where((l) => l.isPending).length;

  /// 已服数量
  int get takenCount => todayPending.where((l) => l.status == MedicationStatus.taken).length;

  /// 跳过/漏服数量
  int get skippedCount => todayPending.where((l) => l.status == MedicationStatus.skipped).length;

  /// 判断指定记录是否正在提交中
  bool isSubmitting(String logKey) => submittingKeys.contains(logKey);
}

/// 用药状态 Notifier
class MedicationNotifier extends StateNotifier<MedicationState> {
  final MedicationService _service;
  final OfflineQueueService _offlineQueue;
  final ConnectivityService _connectivity;

  MedicationNotifier(this._service, this._offlineQueue, this._connectivity) : super(const MedicationState());

  /// 生成防重复提交的 key
  String logKey(MedicationLog log) => '${log.planId}_${log.scheduledAt.toIso8601String()}';

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

  /// 统一更新用药状态（防重复提交保护 + loading 状态 + 离线支持）
  ///
  /// 将 markAsTaken / markAsSkipped 的公共逻辑集中处理：
  /// 防重复提交检查、构建数据、离线入队、网络请求+失败回退、UI更新。
  /// [status] 为 taken 时自动附加 takenAt 时间戳。
  Future<bool> _updateMedicationStatus(MedicationLog log, MedicationStatus status) async {
    final key = logKey(log);
    // 防重复提交：已在提交中的记录直接返回
    if (state.isSubmitting(key)) return false;
    state = state.copyWith(submittingKeys: {...state.submittingKeys, key});

    // 构建用药日志数据，taken 时附加实际服用时间
    final medicationData = <String, dynamic>{
      'planId': log.planId,
      'status': status.value,
      'scheduledAt': log.scheduledAt.toIso8601String(),
    };
    if (status == MedicationStatus.taken) {
      medicationData['takenAt'] = DateTime.now().toUtc().toIso8601String();
    }

    // 离线时直接入队，乐观更新 UI
    if (!_connectivity.isOnline) {
      await _offlineQueue.enqueue('medication', medicationData);
      final updated = log.copyWith(status: status);
      final newList = _replaceByPlanAndTime(state.todayPending, updated);
      state = state.copyWith(
        todayPending: newList,
        submittingKeys: {...state.submittingKeys}..remove(key),
      );
      return true;
    }

    try {
      final updated = await _service.recordLog(
        planId: log.planId,
        status: status,
        scheduledAt: log.scheduledAt,
      );
      final newList = _replaceByPlanAndTime(state.todayPending, updated);
      state = state.copyWith(
        todayPending: newList,
        submittingKeys: {...state.submittingKeys}..remove(key),
      );
      return true;
    } catch (e) {
      // 网络请求失败，入队离线队列，乐观更新 UI
      await _offlineQueue.enqueue('medication', medicationData);
      final updated = log.copyWith(status: status);
      final newList = _replaceByPlanAndTime(state.todayPending, updated);
      state = state.copyWith(
        todayPending: newList,
        submittingKeys: {...state.submittingKeys}..remove(key),
      );
      return true;
    }
  }

  /// 标记已服用
  Future<bool> markAsTaken(MedicationLog log) =>
      _updateMedicationStatus(log, MedicationStatus.taken);

  /// 标记跳过
  Future<bool> markAsSkipped(MedicationLog log) =>
      _updateMedicationStatus(log, MedicationStatus.skipped);
}

/// 用药状态 Provider
final medicationProvider =
    StateNotifierProvider<MedicationNotifier, MedicationState>((ref) {
  final service = ref.watch(medicationServiceProvider);
  final offlineQueue = ref.watch(offlineQueueServiceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return MedicationNotifier(service, offlineQueue, connectivity);
});
