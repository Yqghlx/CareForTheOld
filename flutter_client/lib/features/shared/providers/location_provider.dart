import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../services/location_service.dart';
import '../../../shared/models/location_record.dart';

/// 位置服务 Provider
final locationServiceProvider = Provider<LocationService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  return LocationService(dio);
});

/// 位置状态
class LocationState {
  final LocationRecord? latestLocation;
  final List<LocationRecord> history;
  final bool isLoading;
  final String? error;

  const LocationState({
    this.latestLocation,
    this.history = const [],
    this.isLoading = false,
    this.error,
  });

  LocationState copyWith({
    LocationRecord? latestLocation,
    List<LocationRecord>? history,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearLatest = false,
  }) {
    return LocationState(
      latestLocation: clearLatest ? null : (latestLocation ?? this.latestLocation),
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 位置状态 Notifier
class LocationNotifier extends StateNotifier<LocationState> {
  final LocationService _service;

  LocationNotifier(this._service) : super(const LocationState());

  /// 上报位置
  Future<LocationRecord?> reportLocation(double latitude, double longitude) async {
    try {
      final record = await _service.reportLocation(latitude, longitude);
      state = state.copyWith(latestLocation: record);
      return record;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// 加载最新位置
  Future<void> loadLatestLocation() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final location = await _service.getMyLatestLocation();
      state = state.copyWith(latestLocation: location, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 加载历史记录
  Future<void> loadHistory({int limit = 50}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final history = await _service.getMyHistory(limit: limit);
      state = state.copyWith(history: history, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 加载全部
  Future<void> loadAll({int limit = 50}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final location = await _service.getMyLatestLocation();
      final history = await _service.getMyHistory(limit: limit);
      state = state.copyWith(
        latestLocation: location,
        history: history,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// 位置状态 Provider
final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  final service = ref.watch(locationServiceProvider);
  return LocationNotifier(service);
});

/// 家庭成员位置 Provider（子女查看老人）
final familyMemberLatestLocationProvider =
    FutureProvider.family<LocationRecord?, (String, String)>((ref, params) async {
  final service = ref.watch(locationServiceProvider);
  return service.getFamilyMemberLatestLocation(
    familyId: params.$1,
    memberId: params.$2,
  );
});

/// 家庭成员位置历史 Provider
final familyMemberLocationHistoryProvider =
    FutureProvider.family<List<LocationRecord>, (String, String)>((ref, params) async {
  final service = ref.watch(locationServiceProvider);
  return service.getFamilyMemberHistory(
    familyId: params.$1,
    memberId: params.$2,
    limit: 30,
  );
});