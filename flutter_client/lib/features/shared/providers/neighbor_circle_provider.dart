import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/neighbor_circle.dart';
import '../services/neighbor_circle_service.dart';
import '../../../core/extensions/api_error_extension.dart';

/// 邻里圈服务 Provider
final neighborCircleServiceProvider = Provider<NeighborCircleService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  return NeighborCircleService(dio);
});

/// 邻里圈状态
class NeighborCircleState {
  final NeighborCircle? circle;
  final List<NeighborCircleMember> members;
  final List<NeighborCircle> nearbyCircles;
  final bool isLoading;
  final String? error;

  const NeighborCircleState({
    this.circle,
    this.members = const [],
    this.nearbyCircles = const [],
    this.isLoading = false,
    this.error,
  });

  NeighborCircleState copyWith({
    NeighborCircle? circle,
    List<NeighborCircleMember>? members,
    List<NeighborCircle>? nearbyCircles,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearCircle = false,
  }) {
    return NeighborCircleState(
      circle: clearCircle ? null : (circle ?? this.circle),
      members: members ?? this.members,
      nearbyCircles: nearbyCircles ?? this.nearbyCircles,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// 是否已加入邻里圈
  bool get hasCircle => circle != null;
}

/// 邻里圈状态 Notifier
class NeighborCircleNotifier extends StateNotifier<NeighborCircleState> {
  final NeighborCircleService _service;

  NeighborCircleNotifier(this._service) : super(const NeighborCircleState());

  /// 加载当前用户的邻里圈信息
  Future<void> loadMyCircle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final circle = await _service.getMyCircle();
      if (!mounted) return;
      state = state.copyWith(circle: circle, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: errorMessageFrom(e));
    }
  }

  /// 创建邻里圈
  Future<bool> createCircle({
    required String circleName,
    required double latitude,
    required double longitude,
    double radiusMeters = 500,
  }) async {
    state = state.copyWith(clearError: true);
    try {
      final circle = await _service.createCircle(
        circleName: circleName,
        centerLatitude: latitude,
        centerLongitude: longitude,
        radiusMeters: radiusMeters,
      );
      if (!mounted) return false;
      state = state.copyWith(circle: circle);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(error: errorMessageFrom(e));
      return false;
    }
  }

  /// 通过邀请码加入邻里圈
  Future<bool> joinCircle(String inviteCode) async {
    state = state.copyWith(clearError: true);
    try {
      final circle = await _service.joinCircle(inviteCode);
      if (!mounted) return false;
      state = state.copyWith(circle: circle);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(error: errorMessageFrom(e));
      return false;
    }
  }

  /// 退出邻里圈
  Future<bool> leaveCircle() async {
    final circleId = state.circle?.id;
    if (circleId == null) {
      state = state.copyWith(error: '未加入邻里圈');
      return false;
    }
    state = state.copyWith(clearError: true);
    try {
      await _service.leaveCircle(circleId);
      if (!mounted) return false;
      state = state.copyWith(clearCircle: true, members: []);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(error: errorMessageFrom(e));
      return false;
    }
  }

  /// 加载成员列表
  Future<void> loadMembers() async {
    final circleId = state.circle?.id;
    if (circleId == null) {
      state = state.copyWith(error: '未加入邻里圈');
      return;
    }
    try {
      final members = await _service.getMembers(circleId);
      if (!mounted) return;
      state = state.copyWith(members: members);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: errorMessageFrom(e));
    }
  }

  /// 搜索附近的邻里圈
  Future<void> searchNearby({
    required double latitude,
    required double longitude,
    double radius = AppTheme.defaultNeighborSearchRadius,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final circles = await _service.searchNearbyCircles(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
      );
      if (!mounted) return;
      state = state.copyWith(nearbyCircles: circles, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: errorMessageFrom(e));
    }
  }

  /// 刷新邀请码
  Future<bool> refreshInviteCode() async {
    final circleId = state.circle?.id;
    if (circleId == null) {
      state = state.copyWith(error: '未加入邻里圈');
      return false;
    }
    try {
      final circle = await _service.refreshInviteCode(circleId);
      if (!mounted) return false;
      state = state.copyWith(circle: circle);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(error: errorMessageFrom(e));
      return false;
    }
  }
}

/// 邻里圈状态 Provider
final neighborCircleProvider =
    StateNotifierProvider<NeighborCircleNotifier, NeighborCircleState>((ref) {
  final service = ref.watch(neighborCircleServiceProvider);
  return NeighborCircleNotifier(service);
});
