import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/api_endpoints.dart';

/// 健康报告服务
class HealthReportService {
  final Dio _dio;

  HealthReportService(this._dio);

  /// 下载并分享健康报告
  /// [days] 报告天数范围（7或30）
  /// [elderId] 老人ID（子女端导出老人报告时使用）
  /// [familyId] 家庭ID（子女端导出老人报告时使用）
  Future<bool> downloadAndShareReport({
    required int days,
    String? elderId,
    String? familyId,
  }) async {
    try {
      // 构建请求URL
      String url;
      if (elderId != null && familyId != null) {
        // 子女端导出老人报告
        url = ApiEndpoints.healthReport(familyId: familyId, elderId: elderId, days: days);
      } else {
        // 老人端导出自己的报告
        url = ApiEndpoints.healthReport(days: days);
      }

      // 下载PDF
      final response = await _dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      // 保存到临时目录
      final tempDir = await getTemporaryDirectory();
      final dateFormat = DateFormat('yyyyMMdd');
      final fileName = '健康报告_${dateFormat.format(DateTime.now())}.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response.data as List<int>);

      // 分享文件
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName,
      );

      return true;
    } catch (e) {
      debugPrint('导出报告失败: $e');
      return false;
    }
  }
}

/// Provider
final healthReportServiceProvider = Provider<HealthReportService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  return HealthReportService(dio);
});