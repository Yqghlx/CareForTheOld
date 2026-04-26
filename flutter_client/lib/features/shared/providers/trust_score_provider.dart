import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../services/trust_score_service.dart';
import 'package:dio/dio.dart';
import '../../../core/extensions/api_error_extension.dart';
import '../../../core/theme/app_theme.dart';

/// 信任评分服务 Provider
final trustScoreServiceProvider = Provider<TrustScoreService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  return TrustScoreService(dio);
});

/// 信任评分状态
class TrustScoreState {
  final List<TrustRankingItem> rankings;
  final double myScore;
  final bool isLoading;
  final String? error;

  const TrustScoreState({
    this.rankings = const [],
    this.myScore = 0,
    this.isLoading = false,
    this.error,
  });

  TrustScoreState copyWith({
    List<TrustRankingItem>? rankings,
    double? myScore,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return TrustScoreState(
      rankings: rankings ?? this.rankings,
      myScore: myScore ?? this.myScore,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 信任评分状态 Notifier
class TrustScoreNotifier extends StateNotifier<TrustScoreState> {
  final TrustScoreService _service;

  TrustScoreNotifier(this._service) : super(const TrustScoreState());

  /// 加载排行榜
  Future<void> loadRanking(String circleId, {int top = 20}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final rankings = await _service.getRanking(circleId, top: top);
      state = state.copyWith(rankings: rankings, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.toDisplayMessage());
    } catch (e) {
      state = state.copyWith(isLoading: false, error: AppTheme.msgOperationFailed);
    }
  }

  /// 加载我的评分
  Future<void> loadMyScore(String circleId) async {
    try {
      final score = await _service.getMyScore(circleId);
      state = state.copyWith(myScore: score);
    } on DioException catch (e) {
      state = state.copyWith(error: e.toDisplayMessage());
    } catch (e) {
      state = state.copyWith(error: AppTheme.msgOperationFailed);
    }
  }
}

/// 信任评分状态 Provider（autoDispose 离开页面时自动释放）
final trustScoreProvider =
    StateNotifierProvider.autoDispose<TrustScoreNotifier, TrustScoreState>(
        (ref) {
  final service = ref.watch(trustScoreServiceProvider);
  return TrustScoreNotifier(service);
});
