import 'package:dio/dio.dart';
import '../../../shared/models/medication_plan.dart';
import '../../../shared/models/medication_log.dart';

/// 用药提醒 API 服务类
class MedicationService {
  final Dio _dio;

  MedicationService(this._dio);

  /// 获取我的用药计划
  Future<List<MedicationPlan>> getMyPlans() async {
    final response = await _dio.get('/medication/plans/me');
    final List<dynamic> dataList = response.data['data'];
    return dataList.map((json) => MedicationPlan.fromJson(json)).toList();
  }

  /// 获取今日待服药列表
  Future<List<MedicationLog>> getTodayPending() async {
    final response = await _dio.get('/medication/today-pending');
    final List<dynamic> dataList = response.data['data'];
    return dataList.map((json) => MedicationLog.fromJson(json)).toList();
  }

  /// 记录用药日志（已服/跳过）
  Future<MedicationLog> recordLog({
    required String planId,
    required MedicationStatus status,
    required DateTime scheduledAt,
    String? note,
  }) async {
    final response = await _dio.post('/medication/logs', data: {
      'planId': planId,
      'status': status.value,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      if (status == MedicationStatus.taken)
        'takenAt': DateTime.now().toUtc().toIso8601String(),
      if (note != null && note.isNotEmpty) 'note': note,
    });
    final data = response.data['data'];
    return MedicationLog.fromJson(data);
  }

  /// 获取我的用药日志
  Future<List<MedicationLog>> getMyLogs({int limit = 50}) async {
    final response = await _dio.get(
      '/medication/logs/me',
      queryParameters: {'limit': limit},
    );
    final List<dynamic> dataList = response.data['data'];
    return dataList.map((json) => MedicationLog.fromJson(json)).toList();
  }
}
