import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../core/helpers/mock_dio_helper.dart';
import 'package:care_for_the_old_client/features/elder/services/health_service.dart';
import 'package:care_for_the_old_client/shared/models/health_record.dart';

void main() {
  late MockDio mockDio;
  late HealthService service;

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    mockDio = MockDio();
    service = HealthService(mockDio);
  });

  // ============================================================
  // createRecord 测试
  // ============================================================
  group('createRecord', () {
    test('成功创建血压记录', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => mockResponse({
          'data': {
            'id': 'r1',
            'userId': 'u1',
            'realName': '测试用户',
            'type': 0,
            'systolic': 120,
            'diastolic': 80,
            'bloodSugar': null,
            'heartRate': null,
            'temperature': null,
            'note': null,
            'recordedAt': '2026-01-01T00:00:00Z',
            'createdAt': '2026-01-01T00:00:00Z',
          },
        }),
      );

      final record = await service.createRecord(
        type: HealthType.bloodPressure,
        systolic: 120,
        diastolic: 80,
      );

      expect(record.systolic, 120);
      expect(record.diastolic, 80);
      expect(record.type, HealthType.bloodPressure);

      verify(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).called(1);
    });

    test('成功创建血糖记录', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => mockResponse({
          'data': {
            'id': 'r2',
            'userId': 'u1',
            'realName': null,
            'type': 1,
            'systolic': null,
            'diastolic': null,
            'bloodSugar': 5.6,
            'heartRate': null,
            'temperature': null,
            'note': '饭后',
            'recordedAt': '2026-01-01T00:00:00Z',
            'createdAt': '2026-01-01T00:00:00Z',
          },
        }),
      );

      final record = await service.createRecord(
        type: HealthType.bloodSugar,
        bloodSugar: 5.6,
        note: '饭后',
      );

      expect(record.bloodSugar, 5.6);
      expect(record.note, '饭后');
    });
  });

  // ============================================================
  // getMyRecords 测试
  // ============================================================
  group('getMyRecords', () {
    test('成功获取记录列表', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
        (_) async => mockResponse({
          'data': [
            {
              'id': 'r1',
              'userId': 'u1',
              'realName': null,
              'type': 0,
              'systolic': 120,
              'diastolic': 80,
              'bloodSugar': null,
              'heartRate': null,
              'temperature': null,
              'note': null,
              'recordedAt': '2026-01-01T00:00:00Z',
              'createdAt': '2026-01-01T00:00:00Z',
            },
            {
              'id': 'r2',
              'userId': 'u1',
              'realName': null,
              'type': 1,
              'systolic': null,
              'diastolic': null,
              'bloodSugar': 5.6,
              'heartRate': null,
              'temperature': null,
              'note': null,
              'recordedAt': '2026-01-02T00:00:00Z',
              'createdAt': '2026-01-02T00:00:00Z',
            },
          ],
        }),
      );

      final records = await service.getMyRecords();

      expect(records.length, 2);
      expect(records[0].systolic, 120);
      expect(records[1].bloodSugar, 5.6);
    });

    test('带类型过滤获取记录', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
        (_) async => mockResponse({
          'data': [
            {
              'id': 'r1',
              'userId': 'u1',
              'realName': null,
              'type': 0,
              'systolic': 120,
              'diastolic': 80,
              'bloodSugar': null,
              'heartRate': null,
              'temperature': null,
              'note': null,
              'recordedAt': '2026-01-01T00:00:00Z',
              'createdAt': '2026-01-01T00:00:00Z',
            },
          ],
        }),
      );

      final records = await service.getMyRecords(type: HealthType.bloodPressure);

      expect(records.length, 1);
      expect(records[0].type, HealthType.bloodPressure);
    });

    test('空列表', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
        (_) async => mockResponse({'data': <dynamic>[]}),
      );

      final records = await service.getMyRecords();

      expect(records, isEmpty);
    });
  });

  // ============================================================
  // getMyStats 测试
  // ============================================================
  group('getMyStats', () {
    test('成功获取统计列表', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
        (_) async => mockResponse({
          'data': [
            {
              'typeName': '血压',
              'average7Days': 120.0,
              'average30Days': 118.0,
              'latestValue': 122.0,
              'latestRecordedAt': '2026-01-15T00:00:00Z',
              'totalCount': 30,
              'trend': 'stable',
              'trendWarning': null,
            },
            {
              'typeName': '血糖',
              'average7Days': 5.5,
              'average30Days': 5.4,
              'latestValue': 5.6,
              'latestRecordedAt': '2026-01-15T00:00:00Z',
              'totalCount': 20,
              'trend': null,
              'trendWarning': null,
            },
          ],
        }),
      );

      final stats = await service.getMyStats();

      expect(stats.length, 2);
      expect(stats[0].typeName, '血压');
      expect(stats[0].average30Days, 118.0);
      expect(stats[1].typeName, '血糖');
    });
  });

  // ============================================================
  // deleteRecord 测试
  // ============================================================
  group('deleteRecord', () {
    test('成功删除记录', () async {
      when(() => mockDio.delete(any())).thenAnswer(
        (_) async => mockResponse({'data': null}),
      );

      await service.deleteRecord('r1');

      verify(() => mockDio.delete('/health/r1')).called(1);
    });
  });

  // ============================================================
  // getFamilyMemberRecords 测试
  // ============================================================
  group('getFamilyMemberRecords', () {
    test('成功获取家庭成员记录', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
        (_) async => mockResponse({
          'data': [
            {
              'id': 'r1',
              'userId': 'elder1',
              'realName': '老人甲',
              'type': 0,
              'systolic': 135,
              'diastolic': 85,
              'bloodSugar': null,
              'heartRate': null,
              'temperature': null,
              'note': null,
              'recordedAt': '2026-01-01T00:00:00Z',
              'createdAt': '2026-01-01T00:00:00Z',
            },
          ],
        }),
      );

      final records = await service.getFamilyMemberRecords(
        familyId: 'f1',
        memberId: 'm1',
      );

      expect(records.length, 1);
      expect(records[0].systolic, 135);
      expect(records[0].realName, '老人甲');
    });
  });

  // ============================================================
  // getFamilyMemberStats 测试
  // ============================================================
  group('getFamilyMemberStats', () {
    test('成功获取家庭成员统计', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
        (_) async => mockResponse({
          'data': [
            {
              'typeName': '血压',
              'average7Days': 125.0,
              'average30Days': 122.0,
              'latestValue': 130.0,
              'latestRecordedAt': '2026-01-15T00:00:00Z',
              'totalCount': 25,
              'trend': 'rising',
              'trendWarning': '近期血压呈上升趋势',
            },
          ],
        }),
      );

      final stats = await service.getFamilyMemberStats(
        familyId: 'f1',
        memberId: 'm1',
      );

      expect(stats.length, 1);
      expect(stats[0].trend, 'rising');
      expect(stats[0].hasWarning, isTrue);
    });
  });

  // ============================================================
  // getMyAnomalyDetection 测试
  // ============================================================
  group('getMyAnomalyDetection', () {
    test('成功获取异常检测结果', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
        (_) async => mockResponse({
          'data': {
            'type': 'BloodPressure',
            'typeName': '血压',
            'baseline': {
              'avgSystolic': 120.0,
              'avgDiastolic': 80.0,
              'avgBloodSugar': null,
              'avgHeartRate': null,
              'avgTemperature': null,
              'baselineDays': 30,
              'baselineRecordCount': 30,
            },
            'anomalies': [],
            'recentStats': {
              'avg7Days': 120.0,
              'stdDev7Days': 5.0,
              'max7Days': 130.0,
              'min7Days': 110.0,
              'recordCount7Days': 7,
              'trend': 'stable',
              'baselineDeviationPercent': 0.0,
            },
            'positiveFeedback': null,
          },
        }),
      );

      final result = await service.getMyAnomalyDetection();

      expect(result.type, 'BloodPressure');
      expect(result.typeName, '血压');
      expect(result.baseline.avgSystolic, 120.0);
      expect(result.anomalies, isEmpty);
      expect(result.hasAnomalies(), isFalse);
    });

    test('带类型参数获取异常检测', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
        (_) async => mockResponse({
          'data': {
            'type': 'BloodSugar',
            'typeName': '血糖',
            'baseline': {
              'avgSystolic': null,
              'avgDiastolic': null,
              'avgBloodSugar': 5.5,
              'avgHeartRate': null,
              'avgTemperature': null,
              'baselineDays': 30,
              'baselineRecordCount': 25,
            },
            'anomalies': [
              {
                'detectedAt': '2026-01-10T00:00:00Z',
                'type': 'spike',
                'description': '血糖突然升高',
                'severityScore': 45.0,
                'anomalyValue': 8.5,
                'baselineValue': 5.5,
                'deviationPercent': 54.5,
                'recommendedAction': '建议清淡饮食',
              },
            ],
            'recentStats': {
              'avg7Days': 6.2,
              'stdDev7Days': 1.1,
              'max7Days': 8.5,
              'min7Days': 4.8,
              'recordCount7Days': 7,
              'trend': 'rising',
              'baselineDeviationPercent': 12.7,
            },
            'positiveFeedback': null,
          },
        }),
      );

      final result = await service.getMyAnomalyDetection(
        type: HealthType.bloodSugar,
      );

      expect(result.type, 'BloodSugar');
      expect(result.hasAnomalies(), isTrue);
      expect(result.anomalies.length, 1);
      expect(result.anomalies[0].severityScore, 45.0);
      expect(result.maxSeverity(), 45.0);
    });
  });

  // ============================================================
  // getFamilyMemberAnomalyDetection 测试
  // ============================================================
  group('getFamilyMemberAnomalyDetection', () {
    test('成功获取家庭成员异常检测', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
        (_) async => mockResponse({
          'data': {
            'type': 'HeartRate',
            'typeName': '心率',
            'baseline': {
              'avgSystolic': null,
              'avgDiastolic': null,
              'avgBloodSugar': null,
              'avgHeartRate': 72.0,
              'avgTemperature': null,
              'baselineDays': 30,
              'baselineRecordCount': 28,
            },
            'anomalies': [],
            'recentStats': {
              'avg7Days': 74.0,
              'stdDev7Days': 3.0,
              'max7Days': 80.0,
              'min7Days': 68.0,
              'recordCount7Days': 7,
              'trend': 'stable',
              'baselineDeviationPercent': 2.8,
            },
            'positiveFeedback': {
              'quality': '极佳',
              'message': '过去一周心率控制极佳',
              'daysStable': 7,
              'coefficientOfVariation': 4.1,
            },
          },
        }),
      );

      final result = await service.getFamilyMemberAnomalyDetection(
        familyId: 'f1',
        memberId: 'm1',
      );

      expect(result.type, 'HeartRate');
      expect(result.positiveFeedback, isNotNull);
      expect(result.positiveFeedback!.quality, '极佳');
      expect(result.positiveFeedback!.daysStable, 7);
    });
  });
}
