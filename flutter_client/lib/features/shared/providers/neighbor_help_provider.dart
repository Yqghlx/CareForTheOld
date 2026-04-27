import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/neighbor_help_request.dart';
import '../services/neighbor_help_service.dart';
import '../../../core/extensions/api_error_extension.dart';

/// 邻里互助服务 Provider
final neighborHelpServiceProvider = Provider<NeighborHelpService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  return NeighborHelpService(dio);
});

/// 邻里互助状态
class NeighborHelpState {
  final List<NeighborHelpRequest> pendingRequests;
  final List<NeighborHelpRequest> history;
  final bool isLoading;
  final String? error;

  const NeighborHelpState({
    this.pendingRequests = const [],
    this.history = const [],
    this.isLoading = false,
    this.error,
  });

  NeighborHelpState copyWith({
    List<NeighborHelpRequest>? pendingRequests,
    List<NeighborHelpRequest>? history,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return NeighborHelpState(
      pendingRequests: pendingRequests ?? this.pendingRequests,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// 是否有待响应的求助
  bool get hasPendingRequests => pendingRequests.isNotEmpty;
}

/// 邻里互助状态 Notifier
class NeighborHelpNotifier extends StateNotifier<NeighborHelpState> {
  final NeighborHelpService _service;

  NeighborHelpNotifier(this._service) : super(const NeighborHelpState());

  /// 加载待响应的求助列表
  Future<void> loadPendingRequests() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final requests = await _service.getPendingRequests();
      state = state.copyWith(pendingRequests: requests, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: errorMessageFrom(e));
    }
  }

  /// 加载互助历史
  Future<void> loadHistory({int skip = 0, int limit = 20}) async {
    try {
      final history = await _service.getHistory(skip: skip, limit: limit);
      state = state.copyWith(history: history);
    } catch (e) {
      state = state.copyWith(error: errorMessageFrom(e));
    }
  }

  /// 接受求助请求
  Future<bool> acceptRequest(String requestId) async {
    state = state.copyWith(clearError: true);
    try {
      await _service.acceptRequest(requestId);
      // 从待响应列表中移除
      final updated = state.pendingRequests
          .where((r) => r.id != requestId)
          .toList();
      state = state.copyWith(pendingRequests: updated);
      return true;
    } catch (e) {
      state = state.copyWith(error: errorMessageFrom(e));
      return false;
    }
  }

  /// 取消求助请求
  Future<bool> cancelRequest(String requestId) async {
    state = state.copyWith(clearError: true);
    try {
      await _service.cancelRequest(requestId);
      return true;
    } catch (e) {
      state = state.copyWith(error: errorMessageFrom(e));
      return false;
    }
  }

  /// 评价互助
  Future<bool> rateRequest({
    required String requestId,
    required int rating,
    String? comment,
  }) async {
    state = state.copyWith(clearError: true);
    try {
      await _service.rateRequest(
        requestId: requestId,
        rating: rating,
        comment: comment,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: errorMessageFrom(e));
      return false;
    }
  }
}

/// 邻里互助状态 Provider
final neighborHelpProvider =
    StateNotifierProvider<NeighborHelpNotifier, NeighborHelpState>((ref) {
  final service = ref.watch(neighborHelpServiceProvider);
  return NeighborHelpNotifier(service);
});
