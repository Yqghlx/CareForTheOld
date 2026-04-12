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

  /// 获取老人的用药计划（子女查看）
  Future<List<MedicationPlan>> getElderPlans(String elderId) async {
    final response = await _dio.get('/medication/plans/elder/$elderId');
    final List<dynamic> dataList = response.data['data'];
    return dataList.map((json) => MedicationPlan.fromJson(json)).toList();
  }

  /// 获取老人的用药日志（子女查看）
  Future<List<MedicationLog>> getElderLogs(String elderId,
      {int limit = 50}) async {
    final response = await _dio.get(
      '/medication/logs/elder/$elderId',
      queryParameters: {'limit': limit},
    );
    final List<dynamic> dataList = response.data['data'];
    return dataList.map((json) => MedicationLog.fromJson(json)).toList();
  }

  /// 创建用药计划（子女为老人创建）
  Future<MedicationPlan> createPlan({
    required String elderId,
    required String medicineName,
    required String dosage,
    required int frequency,
    required List<String> reminderTimes,
    required String startDate,
    String? endDate,
  }) async {
    final response = await _dio.post('/medication/plans', data: {
      'elderId': elderId,
      'medicineName': medicineName,
      'dosage': dosage,
      'frequency': frequency,
      'reminderTimes': reminderTimes,
      'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
    });
    final data = response.data['data'];
    return MedicationPlan.fromJson(data);
  }
}
