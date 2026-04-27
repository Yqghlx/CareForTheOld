import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../services/emergency_service.dart';
import '../../../shared/models/emergency_call.dart';
import '../../../core/extensions/api_error_extension.dart';

/// 紧急呼叫服务 Provider
final emergencyServiceProvider = Provider<EmergencyService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  return EmergencyService(dio);
});

/// 紧急呼叫状态
class EmergencyState {
  final List<EmergencyCall> unreadCalls;
  final List<EmergencyCall> historyCalls;
  final bool isLoading;
  final String? error;

  const EmergencyState({
    this.unreadCalls = const [],
    this.historyCalls = const [],
    this.isLoading = false,
    this.error,
  });

  EmergencyState copyWith({
    List<EmergencyCall>? unreadCalls,
    List<EmergencyCall>? historyCalls,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return EmergencyState(
      unreadCalls: unreadCalls ?? this.unreadCalls,
      historyCalls: historyCalls ?? this.historyCalls,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// 未处理呼叫数量
  int get unreadCount => unreadCalls.length;

  /// 是否有未处理呼叫
  bool get hasUnreadCalls => unreadCalls.isNotEmpty;
}

/// 紧急呼叫状态 Notifier
class EmergencyNotifier extends StateNotifier<EmergencyState> {
  final EmergencyService _service;

  /// 紧急呼叫发送锁，防止重复提交
  bool _isCreatingCall = false;

  EmergencyNotifier(this._service) : super(const EmergencyState());

  /// 加载未处理呼叫（子女端）
  Future<void> loadUnreadCalls() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final calls = await _service.getUnreadCalls();
      state = state.copyWith(unreadCalls: calls, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: errorMessageFrom(e));
    }
  }

  /// 加载历史记录
  Future<void> loadHistory({int limit = 20}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final calls = await _service.getHistory(limit: limit);
      state = state.copyWith(historyCalls: calls, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: errorMessageFrom(e));
    }
  }

  /// 加载全部数据
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final unreadCalls = await _service.getUnreadCalls();
      final historyCalls = await _service.getHistory();
      state = state.copyWith(
        unreadCalls: unreadCalls,
        historyCalls: historyCalls,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: errorMessageFrom(e));
    }
  }

  /// 老人发起紧急呼叫（带防重复提交保护）
  Future<EmergencyCall?> createCall({
    double? latitude,
    double? longitude,
    int? batteryLevel,
  }) async {
    if (_isCreatingCall) return null;
    _isCreatingCall = true;
    try {
      final call = await _service.createCall(
        latitude: latitude,
        longitude: longitude,
        batteryLevel: batteryLevel,
      );
      return call;
    } catch (e) {
      state = state.copyWith(error: errorMessageFrom(e));
      return null;
    } finally {
      _isCreatingCall = false;
    }
  }

  /// 子女标记已处理
  Future<bool> respondCall(String callId) async {
    try {
      final updatedCall = await _service.respondCall(callId);
      // 从未处理列表中移除，更新历史列表
      final newUnreadCalls = state.unreadCalls.where((c) => c.id != callId).toList();
      final newHistoryCalls = state.historyCalls.map((c) {
        if (c.id == callId) return updatedCall;
        return c;
      }).toList();

      // 如果历史列表中没有该呼叫，添加到头部
      if (!newHistoryCalls.any((c) => c.id == callId)) {
        newHistoryCalls.insert(0, updatedCall);
      }

      state = state.copyWith(
        unreadCalls: newUnreadCalls,
        historyCalls: newHistoryCalls,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: errorMessageFrom(e));
      return false;
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// 紧急呼叫状态 Provider
final emergencyProvider =
    StateNotifierProvider<EmergencyNotifier, EmergencyState>((ref) {
  final service = ref.watch(emergencyServiceProvider);
  return EmergencyNotifier(service);
});

/// 未处理呼叫数量 Provider（用于显示红点提示）
final unreadEmergencyCountProvider = Provider<int>((ref) {
  return ref.watch(emergencyProvider).unreadCount;
});