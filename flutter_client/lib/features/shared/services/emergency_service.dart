import 'package:dio/dio.dart';
import '../../../shared/models/emergency_call.dart';
import '../../../core/constants/api_endpoints.dart';

/// 紧急呼叫服务
class EmergencyService {
  final Dio _dio;

  EmergencyService(this._dio);

  /// 老人发起紧急呼叫
  /// [latitude] 纬度（可选）
  /// [longitude] 经度（可选）
  /// [batteryLevel] 电池电量百分比 0~100（可选）
  Future<EmergencyCall> createCall({
    double? latitude,
    double? longitude,
    int? batteryLevel,
  }) async {
    final data = <String, dynamic>{};
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    if (batteryLevel != null) data['batteryLevel'] = batteryLevel;

    final response = await _dio.post(ApiEndpoints.emergency, data: data);
    final responseData = response.data['data'];
    return EmergencyCall.fromJson(responseData);
  }

  /// 获取未处理的紧急呼叫（子女端）
  Future<List<EmergencyCall>> getUnreadCalls() async {
    final response = await _dio.get(ApiEndpoints.emergencyUnread);
    final data = response.data['data'] as List;
    return data.map((e) => EmergencyCall.fromJson(e)).toList();
  }

  /// 获取历史呼叫记录
  Future<List<EmergencyCall>> getHistory({int limit = 20}) async {
    final response = await _dio.get(ApiEndpoints.emergencyHistory, queryParameters: {'limit': limit});
    final data = response.data['data'] as List;
    return data.map((e) => EmergencyCall.fromJson(e)).toList();
  }

  /// 子女标记已处理
  Future<EmergencyCall> respondCall(String callId) async {
    final response = await _dio.put(ApiEndpoints.emergencyRespond(callId));
    final data = response.data['data'];
    return EmergencyCall.fromJson(data);
  }
}