import 'package:dio/dio.dart';
import '../../../shared/models/neighbor_circle.dart';
import '../../../core/constants/api_endpoints.dart';

/// 邻里圈管理 API 服务类
class NeighborCircleService {
  final Dio _dio;

  NeighborCircleService(this._dio);

  /// 获取当前用户加入的邻里圈
  Future<NeighborCircle?> getMyCircle() async {
    final response = await _dio.get(ApiEndpoints.neighborCircleMe);
    final data = response.data['data'];
    if (data == null) return null;
    return NeighborCircle.fromJson(data);
  }

  /// 创建邻里圈
  Future<NeighborCircle> createCircle({
    required String circleName,
    required double centerLatitude,
    required double centerLongitude,
    double radiusMeters = 500,
  }) async {
    final response = await _dio.post(ApiEndpoints.neighborCircle, data: {
      'circleName': circleName,
      'centerLatitude': centerLatitude,
      'centerLongitude': centerLongitude,
      'radiusMeters': radiusMeters,
    });
    final data = response.data['data'];
    return NeighborCircle.fromJson(data);
  }

  /// 获取邻里圈详情
  Future<NeighborCircle> getCircle(String circleId) async {
    final response = await _dio.get(ApiEndpoints.neighborCircleById(circleId));
    final data = response.data['data'];
    return NeighborCircle.fromJson(data);
  }

  /// 获取邻里圈成员列表
  Future<List<NeighborCircleMember>> getMembers(String circleId) async {
    final response = await _dio.get(ApiEndpoints.neighborCircleMembers(circleId));
    final List<dynamic> dataList = response.data['data'];
    return dataList
        .map((json) => NeighborCircleMember.fromJson(json))
        .toList();
  }

  /// 获取附近成员（基于最近位置记录）
  Future<List<NeighborCircleMember>> getNearbyMembers({
    required String circleId,
    required double latitude,
    required double longitude,
    double radius = 500,
  }) async {
    final response = await _dio.get(
      ApiEndpoints.neighborCircleNearbyMembers(circleId),
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
      },
    );
    final List<dynamic> dataList = response.data['data'];
    return dataList
        .map((json) => NeighborCircleMember.fromJson(json))
        .toList();
  }

  /// 通过邀请码加入邻里圈
  Future<NeighborCircle> joinCircle(String inviteCode) async {
    final response = await _dio.post(ApiEndpoints.neighborCircleJoin, data: {
      'inviteCode': inviteCode,
    });
    final data = response.data['data'];
    return NeighborCircle.fromJson(data);
  }

  /// 退出邻里圈（创建者退出则解散）
  Future<void> leaveCircle(String circleId) async {
    await _dio.post(ApiEndpoints.neighborCircleLeave(circleId));
  }

  /// 刷新邀请码（仅圈主可操作）
  Future<NeighborCircle> refreshInviteCode(String circleId) async {
    final response = await _dio.post(ApiEndpoints.neighborCircleRefreshCode(circleId));
    final data = response.data['data'];
    return NeighborCircle.fromJson(data);
  }

  /// 搜索附近的邻里圈
  Future<List<NeighborCircle>> searchNearbyCircles({
    required double latitude,
    required double longitude,
    double radius = 2000,
  }) async {
    final response = await _dio.get(
      ApiEndpoints.neighborCircleSearchNearby,
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
      },
    );
    final List<dynamic> dataList = response.data['data'];
    return dataList
        .map((json) => NeighborCircle.fromJson(json))
        .toList();
  }
}
