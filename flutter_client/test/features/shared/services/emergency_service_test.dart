import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../core/helpers/mock_dio_helper.dart';
import 'package:care_for_the_old_client/features/shared/services/emergency_service.dart';
import 'package:care_for_the_old_client/shared/models/emergency_call.dart';

void main() {
  late MockDio mockDio;
  late EmergencyService service;

  /// 构造 EmergencyCall JSON 测试数据
  Map<String, dynamic> emergencyCallJson({
    String id = 'c1',
    String elderId = 'e1',
    String elderName = '老人',
    String? elderPhoneNumber,
    String familyId = 'f1',
    int status = 0,
    double? latitude = 39.9,
    double? longitude = 116.3,
    int? batteryLevel = 80,
    String? respondedBy,
    String? respondedByRealName,
    String? respondedAt,
    String calledAt = '2026-01-01T00:00:00Z',
  }) {
    return {
      'id': id,
      'elderId': elderId,
      'elderName': elderName,
      'elderPhoneNumber': elderPhoneNumber,
      'familyId': familyId,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'batteryLevel': batteryLevel,
      'respondedBy': respondedBy,
      'respondedByRealName': respondedByRealName,
      'respondedAt': respondedAt,
      'calledAt': calledAt,
    };
  }

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    mockDio = MockDio();
    service = EmergencyService(mockDio);
  });

  // ============================================================
  // createCall 测试
  // ============================================================
  group('createCall', () {
    test('成功发起紧急呼叫 - 含位置和电量', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => mockResponse({
          'data': emergencyCallJson(
            latitude: 39.9,
            longitude: 116.3,
            batteryLevel: 80,
          ),
        }),
      );

      final call = await service.createCall(
        latitude: 39.9,
        longitude: 116.3,
        batteryLevel: 80,
      );

      expect(call.id, 'c1');
      expect(call.elderId, 'e1');
      expect(call.elderName, '老人');
      expect(call.status, EmergencyStatus.pending);
      expect(call.isPending, isTrue);
      expect(call.latitude, 39.9);
      expect(call.longitude, 116.3);
      expect(call.batteryLevel, 80);
      expect(call.hasLocation, isTrue);
      expect(call.batteryText, '80%');

      verify(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).called(1);
    });

    test('成功发起紧急呼叫 - 无位置无电量', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => mockResponse({
          'data': emergencyCallJson(
            latitude: null,
            longitude: null,
            batteryLevel: null,
          ),
        }),
      );

      final call = await service.createCall();

      expect(call.latitude, isNull);
      expect(call.longitude, isNull);
      expect(call.batteryLevel, isNull);
      expect(call.hasLocation, isFalse);
      expect(call.batteryText, '未知');
    });

    test('请求 data 仅包含非空字段', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => mockResponse({
          'data': emergencyCallJson(
            latitude: 39.9,
            longitude: null,
            batteryLevel: null,
          ),
        }),
      );

      await service.createCall(latitude: 39.9);

      // 验证发送的 data 只包含 latitude
      final captured = verify(() => mockDio.post(
            any(),
            data: captureAny(named: 'data'),
          )).captured;

      final data = captured.first as Map<String, dynamic>;
      expect(data.containsKey('latitude'), isTrue);
      expect(data['latitude'], 39.9);
      expect(data.containsKey('longitude'), isFalse);
      expect(data.containsKey('batteryLevel'), isFalse);
    });
  });

  // ============================================================
  // getUnreadCalls 测试
  // ============================================================
  group('getUnreadCalls', () {
    test('成功获取未读呼叫列表', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
        (_) async => mockResponse({
          'data': [
            emergencyCallJson(id: 'c1', elderName: '老人甲', status: 0),
            emergencyCallJson(id: 'c2', elderName: '老人乙', status: 0),
          ],
        }),
      );

      final calls = await service.getUnreadCalls();

      expect(calls.length, 2);
      expect(calls[0].id, 'c1');
      expect(calls[0].elderName, '老人甲');
      expect(calls[1].id, 'c2');
      expect(calls.every((c) => c.isPending), isTrue);
    });

    test('无未读呼叫返回空列表', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
        (_) async => mockResponse({'data': <dynamic>[]}),
      );

      final calls = await service.getUnreadCalls();

      expect(calls, isEmpty);
    });
  });

  // ============================================================
  // getHistory 测试
  // ============================================================
  group('getHistory', () {
    test('成功获取历史记录', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
        (_) async => mockResponse({
          'data': [
            emergencyCallJson(
              id: 'c1',
              status: 1,
              respondedAt: '2026-01-01T00:05:00Z',
            ),
            emergencyCallJson(id: 'c2', status: 0),
          ],
        }),
      );

      final calls = await service.getHistory(limit: 20);

      expect(calls.length, 2);
      expect(calls[0].status, EmergencyStatus.responded);
      expect(calls[0].respondedAt, isNotNull);
      expect(calls[1].status, EmergencyStatus.pending);
    });

    test('自定义 limit 参数', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
        (_) async => mockResponse({'data': <dynamic>[]}),
      );

      await service.getHistory(limit: 50);

      final captured = verify(() => mockDio.get(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;

      final params = captured.first as Map<String, dynamic>;
      expect(params['limit'], 50);
    });
  });

  // ============================================================
  // respondCall 测试
  // ============================================================
  group('respondCall', () {
    test('成功响应呼叫', () async {
      when(() => mockDio.put(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => mockResponse({
          'data': emergencyCallJson(
            id: 'c1',
            status: 1,
            respondedBy: 'child1',
            respondedByRealName: '子女甲',
            respondedAt: '2026-01-01T00:05:00Z',
          ),
        }),
      );

      final call = await service.respondCall('c1');

      expect(call.id, 'c1');
      expect(call.status, EmergencyStatus.responded);
      expect(call.respondedBy, 'child1');
      expect(call.respondedByRealName, '子女甲');
      expect(call.respondedAt, isNotNull);
      expect(call.isPending, isFalse);

      verify(() => mockDio.put('/emergency/c1/respond')).called(1);
    });
  });
}
