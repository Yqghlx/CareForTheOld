import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../shared/models/geo_fence.dart';

/// 电子围栏服务
class GeoFenceService {
  final Dio _dio;

  GeoFenceService(this._dio);

  /// 创建电子围栏
  Future<GeoFence> createFence({
    required String elderId,
    required double centerLatitude,
    required double centerLongitude,
    int radius = 500,
    bool isEnabled = true,
  }) async {
    final response = await _dio.post(ApiEndpoints.geoFence, data: {
      'elderId': elderId,
      'centerLatitude': centerLatitude,
      'centerLongitude': centerLongitude,
      'radius': radius,
      'isEnabled': isEnabled,
    });

    return GeoFence.fromJson(response.data);
  }

  /// 获取老人的电子围栏
  Future<GeoFence?> getElderFence(String elderId) async {
    try {
      final response = await _dio.get(ApiEndpoints.geoFenceByElder(elderId));
      if (response.data == null) return null;
      return GeoFence.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// 更新电子围栏
  Future<GeoFence> updateFence({
    required String fenceId,
    required String elderId,
    required double centerLatitude,
    required double centerLongitude,
    int radius = 500,
    bool isEnabled = true,
  }) async {
    final response = await _dio.put(ApiEndpoints.geoFenceById(fenceId), data: {
      'elderId': elderId,
      'centerLatitude': centerLatitude,
      'centerLongitude': centerLongitude,
      'radius': radius,
      'isEnabled': isEnabled,
    });

    return GeoFence.fromJson(response.data);
  }

  /// 删除电子围栏
  Future<void> deleteFence(String fenceId) async {
    await _dio.delete(ApiEndpoints.geoFenceById(fenceId));
  }
}

/// Provider
final geoFenceServiceProvider = Provider<GeoFenceService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  return GeoFenceService(dio);
});