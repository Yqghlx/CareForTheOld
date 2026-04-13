import 'package:dio/dio.dart';
import '../../../shared/models/emergency_call.dart';

/// 紧急呼叫服务
class EmergencyService {
  final Dio _dio;

  EmergencyService(this._dio);

  /// 老人发起紧急呼叫
  Future<EmergencyCall> createCall() async {
    final response = await _dio.post('/emergency');
    final data = response.data['data'];
    return EmergencyCall.fromJson(data);
  }

  /// 获取未处理的紧急呼叫（子女端）
  Future<List<EmergencyCall>> getUnreadCalls() async {
    final response = await _dio.get('/emergency/unread');
    final data = response.data['data'] as List;
    return data.map((e) => EmergencyCall.fromJson(e)).toList();
  }

  /// 获取历史呼叫记录
  Future<List<EmergencyCall>> getHistory({int limit = 20}) async {
    final response = await _dio.get('/emergency/history', queryParameters: {'limit': limit});
    final data = response.data['data'] as List;
    return data.map((e) => EmergencyCall.fromJson(e)).toList();
  }

  /// 子女标记已处理
  Future<EmergencyCall> respondCall(String callId) async {
    final response = await _dio.put('/emergency/$callId/respond');
    final data = response.data['data'];
    return EmergencyCall.fromJson(data);
  }
}