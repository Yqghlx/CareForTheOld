import 'package:dio/dio.dart';
import '../../../shared/models/location_record.dart';

/// 位置服务
class LocationService {
  final Dio _dio;

  LocationService(this._dio);

  /// 上报位置
  Future<LocationRecord> reportLocation(double latitude, double longitude) async {
    final response = await _dio.post('/location', data: {
      'latitude': latitude,
      'longitude': longitude,
    });
    final data = response.data['data'];
    return LocationRecord.fromJson(data);
  }

  /// 获取我的最新位置
  Future<LocationRecord?> getMyLatestLocation() async {
    final response = await _dio.get('/location/me/latest');
    final data = response.data['data'];
    if (data == null) return null;
    return LocationRecord.fromJson(data);
  }

  /// 获取我的位置历史
  Future<List<LocationRecord>> getMyHistory({int limit = 50}) async {
    final response = await _dio.get('/location/me/history', queryParameters: {'limit': limit});
    final data = response.data['data'] as List;
    return data.map((e) => LocationRecord.fromJson(e)).toList();
  }

  /// 获取家庭成员最新位置
  Future<LocationRecord?> getFamilyMemberLatestLocation({
    required String familyId,
    required String memberId,
  }) async {
    final response = await _dio.get('/location/family/$familyId/member/$memberId/latest');
    final data = response.data['data'];
    if (data == null) return null;
    return LocationRecord.fromJson(data);
  }

  /// 获取家庭成员位置历史
  Future<List<LocationRecord>> getFamilyMemberHistory({
    required String familyId,
    required String memberId,
    int limit = 50,
  }) async {
    final response = await _dio.get(
      '/location/family/$familyId/member/$memberId/history',
      queryParameters: {'limit': limit},
    );
    final data = response.data['data'] as List;
    return data.map((e) => LocationRecord.fromJson(e)).toList();
  }
}