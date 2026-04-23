import 'package:flutter_test/flutter_test.dart';
import 'package:care_for_the_old_client/shared/models/anomaly_detection.dart';

/// 异常检测模型序列化与逻辑测试
void main() {
  // ============================================================
  // AnomalyType 扩展测试
  // ============================================================
  group('AnomalyType', () {
    test('所有类型都有 label', () {
      for (final type in AnomalyType.values) {
        expect(type.label, isNotEmpty);
      }
    });

    test('所有类型都有 description', () {
      for (final type in AnomalyType.values) {
        expect(type.description, isNotEmpty);
      }
    });

    test('类型标签正确', () {
      expect(AnomalyType.spike.label, '峰值异常');
      expect(AnomalyType.continuousHigh.label, '持续偏高');
      expect(AnomalyType.continuousLow.label, '持续偏低');
      expect(AnomalyType.acceleration.label, '上升加速');
      expect(AnomalyType.volatility.label, '波动增大');
    });
  });

  // ============================================================
  // PersonalBaseline 序列化测试
  // ============================================================
  group('PersonalBaseline', () {
    test('完整 JSON 反序列化', () {
      final json = {
        'avgSystolic': 120.5,
        'avgDiastolic': 80.0,
        'avgBloodSugar': 5.5,
        'avgHeartRate': 72.0,
        'avgTemperature': 36.5,
        'baselineDays': 30,
        'baselineRecordCount': 25,
      };

      final baseline = PersonalBaseline.fromJson(json);

      expect(baseline.avgSystolic, 120.5);
      expect(baseline.avgDiastolic, 80.0);
      expect(baseline.avgBloodSugar, 5.5);
      expect(baseline.avgHeartRate, 72.0);
      expect(baseline.avgTemperature, 36.5);
      expect(baseline.baselineDays, 30);
      expect(baseline.baselineRecordCount, 25);
    });

    test('空 JSON 使用默认值', () {
      final baseline = PersonalBaseline.fromJson({});

      expect(baseline.avgSystolic, isNull);
      expect(baseline.avgDiastolic, isNull);
      expect(baseline.baselineDays, 30);
      expect(baseline.baselineRecordCount, 0);
    });

    test('序列化再反序列化保持一致', () {
      const baseline = PersonalBaseline(
        avgSystolic: 125.0,
        avgBloodSugar: 6.2,
        avgHeartRate: 78.0,
        baselineDays: 25,
        baselineRecordCount: 20,
      );

      final json = baseline.toJson();
      final restored = PersonalBaseline.fromJson(json);

      expect(restored.avgSystolic, baseline.avgSystolic);
      expect(restored.avgBloodSugar, baseline.avgBloodSugar);
      expect(restored.avgHeartRate, baseline.avgHeartRate);
      expect(restored.baselineDays, baseline.baselineDays);
      expect(restored.baselineRecordCount, baseline.baselineRecordCount);
    });
  });

  // ============================================================
  // AnomalyEvent 测试
  // ============================================================
  group('AnomalyEvent', () {
    test('完整 JSON 反序列化', () {
      final json = {
        'detectedAt': '2026-04-20T10:30:00Z',
        'type': 'spike',
        'description': '血压值突增至180，超过基线50%',
        'severityScore': 75.0,
        'anomalyValue': 180.0,
        'baselineValue': 120.0,
        'deviationPercent': 50.0,
      };

      final event = AnomalyEvent.fromJson(json);

      expect(event.detectedAt, DateTime.parse('2026-04-20T10:30:00Z'));
      expect(event.type, AnomalyType.spike);
      expect(event.description, contains('突增'));
      expect(event.severityScore, 75.0);
      expect(event.anomalyValue, 180.0);
      expect(event.baselineValue, 120.0);
      expect(event.deviationPercent, 50.0);
    });

    test('severityLevel 正确分级', () {
      final normal = AnomalyEvent(
        detectedAt: DateTime(2026, 1, 1), severityScore: 20, type: AnomalyType.spike, description: '',
      );
      expect(normal.severityLevel, '正常关注');

      final warning = AnomalyEvent(
        detectedAt: DateTime(2026, 1, 1), severityScore: 50, type: AnomalyType.continuousHigh, description: '',
      );
      expect(warning.severityLevel, '需要关注');

      final critical = AnomalyEvent(
        detectedAt: DateTime(2026, 1, 1), severityScore: 80, type: AnomalyType.volatility, description: '',
      );
      expect(critical.severityLevel, '需要重视');
    });

    test('边界值 33 和 66', () {
      final at33 = AnomalyEvent(
        detectedAt: DateTime(2026, 1, 1), severityScore: 33, type: AnomalyType.spike, description: '',
      );
      expect(at33.severityLevel, '需要关注');

      final at66 = AnomalyEvent(
        detectedAt: DateTime(2026, 1, 1), severityScore: 66, type: AnomalyType.spike, description: '',
      );
      expect(at66.severityLevel, '需要重视');
    });

    test('序列化再反序列化保持一致', () {
      final now = DateTime.parse('2026-04-23T12:00:00Z');
      final event = AnomalyEvent(
        detectedAt: now,
        type: AnomalyType.continuousLow,
        description: '血糖持续偏低',
        severityScore: 45.0,
        anomalyValue: 3.2,
        baselineValue: 5.5,
        deviationPercent: -41.8,
      );

      final json = event.toJson();
      final restored = AnomalyEvent.fromJson(json);

      expect(restored.detectedAt, event.detectedAt);
      expect(restored.type, event.type);
      expect(restored.description, event.description);
      expect(restored.severityScore, event.severityScore);
      expect(restored.anomalyValue, event.anomalyValue);
      expect(restored.baselineValue, event.baselineValue);
      expect(restored.deviationPercent, event.deviationPercent);
    });
  });

  // ============================================================
  // RecentStatsSummary 测试
  // ============================================================
  group('RecentStatsSummary', () {
    test('完整 JSON 反序列化', () {
      final json = {
        'avg7Days': 125.0,
        'stdDev7Days': 8.5,
        'max7Days': 145.0,
        'min7Days': 110.0,
        'recordCount7Days': 7,
        'trend': 'rising',
        'baselineDeviationPercent': 4.2,
      };

      final stats = RecentStatsSummary.fromJson(json);

      expect(stats.avg7Days, 125.0);
      expect(stats.stdDev7Days, 8.5);
      expect(stats.max7Days, 145.0);
      expect(stats.min7Days, 110.0);
      expect(stats.recordCount7Days, 7);
      expect(stats.trend, 'rising');
      expect(stats.baselineDeviationPercent, 4.2);
    });

    test('空 JSON 使用默认值', () {
      final stats = RecentStatsSummary.fromJson({});

      expect(stats.avg7Days, isNull);
      expect(stats.stdDev7Days, isNull);
      expect(stats.recordCount7Days, 0);
      expect(stats.trend, isNull);
    });

    test('序列化再反序列化保持一致', () {
      const stats = RecentStatsSummary(
        avg7Days: 130.0,
        stdDev7Days: 12.0,
        max7Days: 155.0,
        min7Days: 105.0,
        recordCount7Days: 6,
        trend: 'falling',
        baselineDeviationPercent: -8.5,
      );

      final json = stats.toJson();
      final restored = RecentStatsSummary.fromJson(json);

      expect(restored.avg7Days, stats.avg7Days);
      expect(restored.stdDev7Days, stats.stdDev7Days);
      expect(restored.max7Days, stats.max7Days);
      expect(restored.min7Days, stats.min7Days);
      expect(restored.recordCount7Days, stats.recordCount7Days);
      expect(restored.trend, stats.trend);
      expect(restored.baselineDeviationPercent, stats.baselineDeviationPercent);
    });
  });

  // ============================================================
  // TrendAnomalyDetectionResponse 测试
  // ============================================================
  group('TrendAnomalyDetectionResponse', () {
    test('完整 JSON 反序列化', () {
      final json = {
        'type': 'BloodPressure',
        'typeName': 'BloodPressure',
        'baseline': {
          'avgSystolic': 122.0,
          'avgDiastolic': 80.0,
          'baselineDays': 30,
          'baselineRecordCount': 28,
        },
        'anomalies': [
          {
            'detectedAt': '2026-04-20T10:00:00Z',
            'type': 'spike',
            'description': '血压突增',
            'severityScore': 65.0,
            'anomalyValue': 180.0,
            'baselineValue': 122.0,
            'deviationPercent': 47.5,
          },
        ],
        'recentStats': {
          'avg7Days': 130.0,
          'stdDev7Days': 15.0,
          'recordCount7Days': 7,
          'trend': 'rising',
        },
      };

      final response = TrendAnomalyDetectionResponse.fromJson(json);

      expect(response.type, 'BloodPressure');
      expect(response.typeName, 'BloodPressure');
      expect(response.baseline.avgSystolic, 122.0);
      expect(response.anomalies.length, 1);
      expect(response.anomalies[0].type, AnomalyType.spike);
      expect(response.anomalies[0].severityScore, 65.0);
      expect(response.recentStats.avg7Days, 130.0);
    });

    test('无异常事件', () {
      final json = {
        'type': 'HeartRate',
        'typeName': 'HeartRate',
        'baseline': {
          'baselineDays': 30,
          'baselineRecordCount': 0,
        },
        'anomalies': [],
        'recentStats': {
          'avg7Days': 72.0,
          'recordCount7Days': 7,
        },
      };

      final response = TrendAnomalyDetectionResponse.fromJson(json);

      expect(response.hasAnomalies(), isFalse);
      expect(response.maxSeverity(), 0);
    });

    test('有异常事件', () {
      final json = <String, dynamic>{
        'type': 'BloodSugar',
        'typeName': 'BloodSugar',
        'baseline': <String, dynamic>{},
        'anomalies': [
          <String, dynamic>{
            'detectedAt': '2026-04-20T10:00:00Z',
            'type': 'continuousHigh',
            'description': '血糖持续偏高',
            'severityScore': 40.0,
          },
          <String, dynamic>{
            'detectedAt': '2026-04-21T10:00:00Z',
            'type': 'spike',
            'description': '血糖突增',
            'severityScore': 80.0,
          },
        ],
        'recentStats': <String, dynamic>{},
      };

      final response = TrendAnomalyDetectionResponse.fromJson(json);

      expect(response.hasAnomalies(), isTrue);
      expect(response.maxSeverity(), 80.0);
    });

    test('maxSeverity 多个异常取最大值', () {
      final json = <String, dynamic>{
        'type': 'Temperature',
        'typeName': 'Temperature',
        'baseline': <String, dynamic>{},
        'anomalies': [
          <String, dynamic>{
            'detectedAt': '2026-04-19T10:00:00Z',
            'type': 'spike',
            'description': 'a',
            'severityScore': 30.0,
          },
          <String, dynamic>{
            'detectedAt': '2026-04-20T10:00:00Z',
            'type': 'volatility',
            'description': 'b',
            'severityScore': 90.0,
          },
          <String, dynamic>{
            'detectedAt': '2026-04-21T10:00:00Z',
            'type': 'continuousLow',
            'description': 'c',
            'severityScore': 55.0,
          },
        ],
        'recentStats': <String, dynamic>{},
      };

      final response = TrendAnomalyDetectionResponse.fromJson(json);

      expect(response.anomalies.length, 3);
      expect(response.maxSeverity(), 90.0);
    });

    test('嵌套对象序列化验证', () {
      final json = <String, dynamic>{
        'type': 'BloodPressure',
        'typeName': 'BloodPressure',
        'baseline': <String, dynamic>{
          'avgSystolic': 120.0,
          'baselineDays': 30,
          'baselineRecordCount': 28,
        },
        'anomalies': [
          <String, dynamic>{
            'detectedAt': '2026-04-20T10:00:00Z',
            'type': 'spike',
            'description': '血压突增至180',
            'severityScore': 75.0,
            'anomalyValue': 180.0,
            'baselineValue': 120.0,
          },
        ],
        'recentStats': <String, dynamic>{
          'avg7Days': 130.0,
          'recordCount7Days': 7,
          'trend': 'rising',
        },
      };

      final response = TrendAnomalyDetectionResponse.fromJson(json);

      // 验证顶层字段
      expect(response.type, 'BloodPressure');
      expect(response.typeName, 'BloodPressure');

      // 验证嵌套 baseline
      expect(response.baseline.avgSystolic, 120.0);
      expect(response.baseline.baselineDays, 30);
      expect(response.baseline.baselineRecordCount, 28);

      // 验证嵌套 anomalies
      expect(response.anomalies.length, 1);
      expect(response.anomalies[0].type, AnomalyType.spike);
      expect(response.anomalies[0].severityScore, 75.0);
      expect(response.anomalies[0].anomalyValue, 180.0);

      // 验证嵌套 recentStats
      expect(response.recentStats.avg7Days, 130.0);
      expect(response.recentStats.recordCount7Days, 7);
      expect(response.recentStats.trend, 'rising');
    });
  });
}
