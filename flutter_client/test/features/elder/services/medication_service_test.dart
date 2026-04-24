import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../core/helpers/mock_dio_helper.dart';
import 'package:care_for_the_old_client/features/elder/services/medication_service.dart';
import 'package:care_for_the_old_client/shared/models/medication_plan.dart';
import 'package:care_for_the_old_client/shared/models/medication_log.dart';

void main() {
  late MockDio mockDio;
  late MedicationService service;

  setUpAll(() => registerFallbackValues());

  setUp(() {
    mockDio = MockDio();
    service = MedicationService(mockDio);
  });

  /// --- 测试数据常量 ---
  const planJson = {
    'id': 'p1',
    'elderId': 'e1',
    'elderName': '张大爷',
    'medicineName': '阿司匹林',
    'dosage': '1片',
    'frequency': 1,
    'reminderTimes': ['08:00', '20:00'],
    'startDate': '2026-01-01',
    'endDate': null,
    'isActive': true,
    'createdAt': '2026-01-01T00:00:00Z',
    'updatedAt': '2026-01-01T00:00:00Z',
  };

  const logJson = {
    'id': 'l1',
    'planId': 'p1',
    'medicineName': '阿司匹林',
    'elderId': 'e1',
    'elderName': '张大爷',
    'status': 0,
    'scheduledAt': '2026-01-01T08:00:00Z',
    'takenAt': '2026-01-01T08:05:00Z',
    'note': '饭后服用',
  };

  // ------------------------------------------------------------------
  // getMyPlans
  // ------------------------------------------------------------------
  group('getMyPlans', () {
    test('成功获取我的用药计划列表', () async {
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => mockResponse({'data': [planJson]}));

      final result = await service.getMyPlans();

      expect(result, isA<List<MedicationPlan>>());
      expect(result.length, 1);
      expect(result.first.id, 'p1');
      expect(result.first.medicineName, '阿司匹林');
      expect(result.first.dosage, '1片');
      expect(result.first.frequency, Frequency.twiceDaily);
      expect(result.first.reminderTimes, ['08:00', '20:00']);
      expect(result.first.isActive, true);
      verify(() => mockDio.get('/medication/plans/me')).called(1);
    });

    test('无计划时返回空列表', () async {
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => mockResponse({'data': <Map<String, dynamic>>[]}));

      final result = await service.getMyPlans();

      expect(result, isEmpty);
    });
  });

  // ------------------------------------------------------------------
  // getTodayPending
  // ------------------------------------------------------------------
  group('getTodayPending', () {
    test('成功获取今日待服药列表', () async {
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => mockResponse({'data': [logJson]}));

      final result = await service.getTodayPending();

      expect(result, isA<List<MedicationLog>>());
      expect(result.length, 1);
      expect(result.first.id, 'l1');
      expect(result.first.planId, 'p1');
      expect(result.first.medicineName, '阿司匹林');
      expect(result.first.status, MedicationStatus.taken);
      verify(() => mockDio.get('/medication/today-pending')).called(1);
    });

    test('今日无待服药记录返回空列表', () async {
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => mockResponse({'data': <Map<String, dynamic>>[]}));

      final result = await service.getTodayPending();

      expect(result, isEmpty);
    });
  });

  // ------------------------------------------------------------------
  // recordLog
  // ------------------------------------------------------------------
  group('recordLog', () {
    test('记录已服药日志（status==taken），请求中包含 takenAt', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({'data': logJson}));

      final scheduledAt = DateTime(2026, 1, 1, 8, 0, 0);
      final result = await service.recordLog(
        planId: 'p1',
        status: MedicationStatus.taken,
        scheduledAt: scheduledAt,
        note: '饭后服用',
      );

      expect(result, isA<MedicationLog>());
      expect(result.id, 'l1');

      // 验证发送的 data 中包含 takenAt 和正确的 status 值
      final captured = verify(() => mockDio.post(
        '/medication/logs',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['planId'], 'p1');
      expect(data['status'], MedicationStatus.taken.value);
      expect(data['scheduledAt'], isNotNull);
      expect(data.containsKey('takenAt'), isTrue);
      expect(data['note'], '饭后服用');
    });

    test('记录跳过日志（status==skipped），请求中不包含 takenAt', () async {
      final skippedLogJson = Map<String, dynamic>.from(logJson)
        ..['status'] = 1
        ..['takenAt'] = null;

      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({'data': skippedLogJson}));

      final scheduledAt = DateTime(2026, 1, 1, 8, 0, 0);
      final result = await service.recordLog(
        planId: 'p1',
        status: MedicationStatus.skipped,
        scheduledAt: scheduledAt,
      );

      expect(result, isA<MedicationLog>());

      final captured = verify(() => mockDio.post(
        '/medication/logs',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['status'], MedicationStatus.skipped.value);
      expect(data.containsKey('takenAt'), isFalse);
      expect(data.containsKey('note'), isFalse);
    });
  });

  // ------------------------------------------------------------------
  // getMyLogs
  // ------------------------------------------------------------------
  group('getMyLogs', () {
    test('使用默认 limit 获取我的用药日志', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenAnswer((_) async => mockResponse({'data': [logJson]}));

      final result = await service.getMyLogs();

      expect(result.length, 1);
      expect(result.first.id, 'l1');

      final captured = verify(() => mockDio.get(
        '/medication/logs/me',
        queryParameters: captureAny(named: 'queryParameters'),
      )).captured;
      final params = captured.first as Map<String, dynamic>;
      expect(params['limit'], 50);
    });

    test('使用自定义 limit 获取我的用药日志', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenAnswer((_) async => mockResponse({'data': <Map<String, dynamic>>[]}));

      await service.getMyLogs(limit: 10);

      final captured = verify(() => mockDio.get(
        '/medication/logs/me',
        queryParameters: captureAny(named: 'queryParameters'),
      )).captured;
      final params = captured.first as Map<String, dynamic>;
      expect(params['limit'], 10);
    });
  });

  // ------------------------------------------------------------------
  // getElderPlans
  // ------------------------------------------------------------------
  group('getElderPlans', () {
    test('成功获取老人的用药计划列表', () async {
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => mockResponse({'data': [planJson]}));

      final result = await service.getElderPlans('e1');

      expect(result.length, 1);
      expect(result.first.elderId, 'e1');
      verify(() => mockDio.get('/medication/plans/elder/e1')).called(1);
    });
  });

  // ------------------------------------------------------------------
  // getElderLogs
  // ------------------------------------------------------------------
  group('getElderLogs', () {
    test('不带日期参数获取老人用药日志', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenAnswer((_) async => mockResponse({'data': [logJson]}));

      final result = await service.getElderLogs('e1');

      expect(result.length, 1);
      final captured = verify(() => mockDio.get(
        '/medication/logs/elder/e1',
        queryParameters: captureAny(named: 'queryParameters'),
      )).captured;
      final params = captured.first as Map<String, dynamic>;
      expect(params['limit'], 50);
      expect(params.containsKey('date'), isFalse);
    });

    test('带日期参数获取老人用药日志', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenAnswer((_) async => mockResponse({'data': [logJson]}));

      final result = await service.getElderLogs('e1', date: '2026-01-01');

      expect(result.length, 1);
      final captured = verify(() => mockDio.get(
        '/medication/logs/elder/e1',
        queryParameters: captureAny(named: 'queryParameters'),
      )).captured;
      final params = captured.first as Map<String, dynamic>;
      expect(params['limit'], 50);
      expect(params['date'], '2026-01-01');
    });
  });

  // ------------------------------------------------------------------
  // createPlan
  // ------------------------------------------------------------------
  group('createPlan', () {
    test('成功创建用药计划（不带 endDate）', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({'data': planJson}));

      final result = await service.createPlan(
        elderId: 'e1',
        medicineName: '阿司匹林',
        dosage: '1片',
        frequency: 1,
        reminderTimes: ['08:00', '20:00'],
        startDate: '2026-01-01',
      );

      expect(result, isA<MedicationPlan>());
      expect(result.id, 'p1');

      final captured = verify(() => mockDio.post(
        '/medication/plans',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['elderId'], 'e1');
      expect(data['medicineName'], '阿司匹林');
      expect(data['frequency'], 1);
      expect(data.containsKey('endDate'), isFalse);
    });

    test('创建用药计划（带 endDate）', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({'data': planJson}));

      await service.createPlan(
        elderId: 'e1',
        medicineName: '阿司匹林',
        dosage: '1片',
        frequency: 1,
        reminderTimes: ['08:00'],
        startDate: '2026-01-01',
        endDate: '2026-06-01',
      );

      final captured = verify(() => mockDio.post(
        '/medication/plans',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['endDate'], '2026-06-01');
    });
  });

  // ------------------------------------------------------------------
  // updatePlan
  // ------------------------------------------------------------------
  group('updatePlan', () {
    test('成功更新用药计划的部分字段', () async {
      when(() => mockDio.put(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({'data': planJson}));

      final result = await service.updatePlan(
        planId: 'p1',
        medicineName: '布洛芬',
        isActive: false,
      );

      expect(result, isA<MedicationPlan>());

      final captured = verify(() => mockDio.put(
        '/medication/plans/p1',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['medicineName'], '布洛芬');
      expect(data['isActive'], false);
      // 未传入的字段不应出现在请求体中
      expect(data.containsKey('dosage'), isFalse);
      expect(data.containsKey('frequency'), isFalse);
      expect(data.containsKey('reminderTimes'), isFalse);
      expect(data.containsKey('endDate'), isFalse);
    });
  });

  // ------------------------------------------------------------------
  // deletePlan
  // ------------------------------------------------------------------
  group('deletePlan', () {
    test('成功删除用药计划', () async {
      when(() => mockDio.delete(any()))
          .thenAnswer((_) async => mockResponse(null));

      await service.deletePlan('p1');

      verify(() => mockDio.delete('/medication/plans/p1')).called(1);
    });
  });
}
