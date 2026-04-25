import 'package:dio/dio.dart';
import '../../../shared/models/health_record.dart';
import '../../../shared/models/health_stats.dart';
import '../../../shared/models/anomaly_detection.dart';

/// 健康记录 API 服务类
class HealthService {
  final Dio _dio;

  HealthService(this._dio);

  /// 创建健康记录
  Future<HealthRecord> createRecord({
    required HealthType type,
    int? systolic,
    int? diastolic,
    double? bloodSugar,
    int? heartRate,
    double? temperature,
    String? note,
  }) async {
    final response = await _dio.post('/health', data: {
      'type': type.name,
      if (systolic != null) 'systolic': systolic,
      if (diastolic != null) 'diastolic': diastolic,
      if (bloodSugar != null) 'bloodSugar': bloodSugar,
      if (heartRate != null) 'heartRate': heartRate,
      if (temperature != null) 'temperature': temperature,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    final data = response.data['data'];
    return HealthRecord.fromJson(data);
  }

  /// 获取我的健康记录列表
  /// [type] 可选过滤类型，传 null 获取全部
  Future<List<HealthRecord>> getMyRecords({
    HealthType? type,
    int limit = 50,
  }) async {
    final queryParams = <String, dynamic>{'limit': limit};
    if (type != null) {
      queryParams['type'] = type.name;
    }
    final response = await _dio.get(
      '/health/me',
      queryParameters: queryParams,
    );
    final List<dynamic> dataList = response.data['data'];
    return dataList.map((json) => HealthRecord.fromJson(json)).toList();
  }

  /// 获取我的健康统计
  Future<List<HealthStats>> getMyStats() async {
    final response = await _dio.get('/health/me/stats');
    final List<dynamic> dataList = response.data['data'];
    return dataList.map((json) => HealthStats.fromJson(json)).toList();
  }

  /// 删除健康记录
  Future<void> deleteRecord(String id) async {
    await _dio.delete('/health/$id');
  }

  /// 获取家庭成员的健康记录（子女查看老人数据）
  Future<List<HealthRecord>> getFamilyMemberRecords({
    required String familyId,
    required String memberId,
    HealthType? type,
    int limit = 50,
  }) async {
    final queryParams = <String, dynamic>{'limit': limit};
    if (type != null) queryParams['type'] = type.value;
    final response = await _dio.get(
      '/health/family/$familyId/member/$memberId',
      queryParameters: queryParams,
    );
    final List<dynamic> dataList = response.data['data'];
    return dataList.map((json) => HealthRecord.fromJson(json)).toList();
  }

  /// 获取家庭成员的健康统计（子女查看老人数据）
  Future<List<HealthStats>> getFamilyMemberStats({
    required String familyId,
    required String memberId,
  }) async {
    final response = await _dio.get(
      '/health/family/$familyId/member/$memberId/stats',
    );
    final List<dynamic> dataList = response.data['data'];
    return dataList.map((json) => HealthStats.fromJson(json)).toList();
  }

  /// 获取我的健康趋势异常检测
  /// [type] 可选健康类型，默认为血压
  Future<TrendAnomalyDetectionResponse> getMyAnomalyDetection({
    HealthType? type,
  }) async {
    final queryParams = <String, dynamic>{};
    if (type != null) queryParams['type'] = type.value;
    final response = await _dio.get(
      '/health/me/anomaly-detection',
      queryParameters: queryParams,
    );
    return TrendAnomalyDetectionResponse.fromJson(response.data['data']);
  }

  /// 获取家庭成员的健康趋势异常检测（子女查看老人）
  /// [type] 可选健康类型，默认为血压
  Future<TrendAnomalyDetectionResponse> getFamilyMemberAnomalyDetection({
    required String familyId,
    required String memberId,
    HealthType? type,
  }) async {
    final queryParams = <String, dynamic>{};
    if (type != null) queryParams['type'] = type.value;
    final response = await _dio.get(
      '/health/family/$familyId/member/$memberId/anomaly-detection',
      queryParameters: queryParams,
    );
    return TrendAnomalyDetectionResponse.fromJson(response.data['data']);
  }
}
