import 'package:dio/dio.dart';
import '../../../shared/models/neighbor_help_request.dart';

/// 邻里互助 API 服务类
class NeighborHelpService {
  final Dio _dio;

  NeighborHelpService(this._dio);

  /// 获取待响应的求助列表
  Future<List<NeighborHelpRequest>> getPendingRequests() async {
    final response = await _dio.get('/neighborhelp/pending');
    final List<dynamic> dataList = response.data['data'];
    return dataList
        .map((json) => NeighborHelpRequest.fromJson(json))
        .toList();
  }

  /// 获取互助历史记录
  Future<List<NeighborHelpRequest>> getHistory({
    int skip = 0,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '/neighborhelp/history',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    final List<dynamic> dataList = response.data['data'];
    return dataList
        .map((json) => NeighborHelpRequest.fromJson(json))
        .toList();
  }

  /// 获取求助请求详情
  Future<NeighborHelpRequest> getRequest(String requestId) async {
    final response = await _dio.get('/neighborhelp/$requestId');
    final data = response.data['data'];
    return NeighborHelpRequest.fromJson(data);
  }

  /// 接受求助请求（第一个接受者生效）
  Future<NeighborHelpRequest> acceptRequest(String requestId) async {
    final response = await _dio.put('/neighborhelp/$requestId/accept');
    final data = response.data['data'];
    return NeighborHelpRequest.fromJson(data);
  }

  /// 取消求助请求
  Future<void> cancelRequest(String requestId) async {
    await _dio.put('/neighborhelp/$requestId/cancel');
  }

  /// 评价互助（1-5 星）
  Future<NeighborHelpRating> rateRequest({
    required String requestId,
    required int rating,
    String? comment,
  }) async {
    final response = await _dio.post('/neighborhelp/$requestId/rate', data: {
      'rating': rating,
      'comment': comment,
    });
    final data = response.data['data'];
    return NeighborHelpRating.fromJson(data);
  }
}
