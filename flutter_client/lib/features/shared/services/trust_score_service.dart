import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';

/// 信任排行榜条目
class TrustRankingItem {
  final int rank;
  final String userId;
  final String userName;
  final int totalHelps;
  final double avgRating;
  final double responseRate;
  final double score;

  const TrustRankingItem({
    required this.rank,
    required this.userId,
    required this.userName,
    required this.totalHelps,
    required this.avgRating,
    required this.responseRate,
    required this.score,
  });

  factory TrustRankingItem.fromJson(Map<String, dynamic> json) {
    return TrustRankingItem(
      rank: json['rank'] as int,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      totalHelps: json['totalHelps'] as int,
      avgRating: (json['avgRating'] as num).toDouble(),
      responseRate: (json['responseRate'] as num).toDouble(),
      score: (json['score'] as num).toDouble(),
    );
  }
}

/// 信任评分 API 服务类
class TrustScoreService {
  final Dio _dio;

  TrustScoreService(this._dio);

  /// 获取圈内信任排行榜
  Future<List<TrustRankingItem>> getRanking(String circleId, {int top = 20}) async {
    final response = await _dio.get(
      ApiEndpoints.trustScoreRanking(circleId),
      queryParameters: {'top': top},
    );
    final List<dynamic> dataList = response.data['data'];
    return dataList.map((json) => TrustRankingItem.fromJson(json)).toList();
  }

  /// 获取我的信任评分
  Future<double> getMyScore(String circleId) async {
    final response = await _dio.get(ApiEndpoints.trustScoreMe(circleId));
    final data = response.data['data'];
    return (data['score'] as num).toDouble();
  }
}
