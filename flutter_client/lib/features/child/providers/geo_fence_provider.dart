import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/geo_fence.dart';
import '../services/geo_fence_service.dart';

/// 电子围栏状态
class GeoFenceState {
  final GeoFence? fence;
  final bool isLoading;
  final String? error;

  const GeoFenceState({
    this.fence,
    this.isLoading = false,
    this.error,
  });

  GeoFenceState copyWith({
    GeoFence? fence,
    bool? isLoading,
    String? error,
  }) {
    return GeoFenceState(
      fence: fence ?? this.fence,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 电子围栏Notifier
class GeoFenceNotifier extends StateNotifier<GeoFenceState> {
  final GeoFenceService _service;

  GeoFenceNotifier(this._service) : super(const GeoFenceState());

  /// 加载老人的围栏
  Future<void> loadFence(String elderId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final fence = await _service.getElderFence(elderId);
      state = state.copyWith(fence: fence, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 创建或更新围栏
  Future<bool> saveFence({
    required String elderId,
    required double centerLatitude,
    required double centerLongitude,
    required int radius,
    bool isEnabled = true,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 如果已有围栏，则更新
      if (state.fence != null) {
        final fence = await _service.updateFence(
          fenceId: state.fence!.id,
          elderId: elderId,
          centerLatitude: centerLatitude,
          centerLongitude: centerLongitude,
          radius: radius,
          isEnabled: isEnabled,
        );
        state = state.copyWith(fence: fence, isLoading: false);
      } else {
        // 创建新围栏
        final fence = await _service.createFence(
          elderId: elderId,
          centerLatitude: centerLatitude,
          centerLongitude: centerLongitude,
          radius: radius,
          isEnabled: isEnabled,
        );
        state = state.copyWith(fence: fence, isLoading: false);
      }
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// 删除围栏
  Future<bool> deleteFence() async {
    if (state.fence == null) return true;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.deleteFence(state.fence!.id);
      state = state.copyWith(fence: null, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// 切换启用状态（通过更新实现）
  Future<bool> toggleEnabled({
    required String elderId,
    required double centerLatitude,
    required double centerLongitude,
    required int radius,
  }) async {
    if (state.fence == null) return false;

    final newEnabled = !state.fence!.isEnabled;
    return saveFence(
      elderId: elderId,
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
      radius: radius,
      isEnabled: newEnabled,
    );
  }
}

/// 指定老人的围栏Provider
final elderGeoFenceProvider = StateNotifierProvider.autoDispose<GeoFenceNotifier, GeoFenceState>((ref) {
  final service = ref.watch(geoFenceServiceProvider);
  return GeoFenceNotifier(service);
});