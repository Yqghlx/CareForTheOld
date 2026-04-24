import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../core/helpers/mock_dio_helper.dart';
import 'package:care_for_the_old_client/features/shared/services/location_service.dart';
import 'package:care_for_the_old_client/shared/models/location_record.dart';

void main() {
  late MockDio mockDio;
  late LocationService service;

  setUpAll(() => registerFallbackValues());

  setUp(() {
    mockDio = MockDio();
    service = LocationService(mockDio);
  });

  /// --- 测试数据常量 ---
  const recordJson = {
    'id': 'loc1',
    'userId': 'u1',
    'realName': '张大爷',
    'latitude': 39.9,
    'longitude': 116.3,
    'recordedAt': '2026-01-01T00:00:00Z',
  };

  // ------------------------------------------------------------------
  // reportLocation
  // ------------------------------------------------------------------
  group('reportLocation', () {
    test('成功上报位置（不含精度）', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({'data': recordJson}));

      final result = await service.reportLocation(39.9, 116.3);

      expect(result, isA<LocationRecord>());
      expect(result.id, 'loc1');
      expect(result.latitude, 39.9);
      expect(result.longitude, 116.3);

      final captured = verify(() => mockDio.post(
        '/location',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['latitude'], 39.9);
      expect(data['longitude'], 116.3);
      expect(data.containsKey('accuracy'), isFalse);
    });

    test('成功上报位置（含精度）', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({'data': recordJson}));

      final result = await service.reportLocation(39.9, 116.3, accuracy: 10.0);

      expect(result, isA<LocationRecord>());

      final captured = verify(() => mockDio.post(
        '/location',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['accuracy'], 10.0);
    });
  });

  // ------------------------------------------------------------------
  // getMyLatestLocation
  // ------------------------------------------------------------------
  group('getMyLatestLocation', () {
    test('成功获取我的最新位置', () async {
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => mockResponse({'data': recordJson}));

      final result = await service.getMyLatestLocation();

      expect(result, isNotNull);
      expect(result!.id, 'loc1');
      expect(result.latitude, 39.9);
      verify(() => mockDio.get('/location/me/latest')).called(1);
    });

    test('data 为 null 时返回 null', () async {
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => mockResponse({'data': null}));

      final result = await service.getMyLatestLocation();

      expect(result, isNull);
    });
  });

  // ------------------------------------------------------------------
  // getMyHistory
  // ------------------------------------------------------------------
  group('getMyHistory', () {
    test('使用默认参数获取我的位置历史', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenAnswer((_) async => mockResponse({'data': [recordJson]}));

      final result = await service.getMyHistory();

      expect(result.length, 1);
      expect(result.first.id, 'loc1');

      final captured = verify(() => mockDio.get(
        '/location/me/history',
        queryParameters: captureAny(named: 'queryParameters'),
      )).captured;
      final params = captured.first as Map<String, dynamic>;
      expect(params['skip'], 0);
      expect(params['limit'], 20);
    });

    test('使用自定义分页参数获取位置历史', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenAnswer((_) async => mockResponse({'data': <Map<String, dynamic>>[]}));

      await service.getMyHistory(skip: 10, limit: 5);

      final captured = verify(() => mockDio.get(
        '/location/me/history',
        queryParameters: captureAny(named: 'queryParameters'),
      )).captured;
      final params = captured.first as Map<String, dynamic>;
      expect(params['skip'], 10);
      expect(params['limit'], 5);
    });

    test('无历史记录时返回空列表', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenAnswer((_) async => mockResponse({'data': <Map<String, dynamic>>[]}));

      final result = await service.getMyHistory();

      expect(result, isEmpty);
    });
  });

  // ------------------------------------------------------------------
  // getFamilyMemberLatestLocation
  // ------------------------------------------------------------------
  group('getFamilyMemberLatestLocation', () {
    test('成功获取家庭成员最新位置', () async {
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => mockResponse({'data': recordJson}));

      final result = await service.getFamilyMemberLatestLocation(
        familyId: 'f1',
        memberId: 'u1',
      );

      expect(result, isNotNull);
      expect(result!.id, 'loc1');
      verify(() => mockDio.get('/location/family/f1/member/u1/latest')).called(1);
    });

    test('家庭成员无位置数据时返回 null', () async {
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => mockResponse({'data': null}));

      final result = await service.getFamilyMemberLatestLocation(
        familyId: 'f1',
        memberId: 'u1',
      );

      expect(result, isNull);
    });
  });

  // ------------------------------------------------------------------
  // getFamilyMemberHistory
  // ------------------------------------------------------------------
  group('getFamilyMemberHistory', () {
    test('使用默认分页参数获取家庭成员位置历史', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenAnswer((_) async => mockResponse({'data': [recordJson]}));

      final result = await service.getFamilyMemberHistory(
        familyId: 'f1',
        memberId: 'u1',
      );

      expect(result.length, 1);
      expect(result.first.id, 'loc1');

      final captured = verify(() => mockDio.get(
        '/location/family/f1/member/u1/history',
        queryParameters: captureAny(named: 'queryParameters'),
      )).captured;
      final params = captured.first as Map<String, dynamic>;
      expect(params['skip'], 0);
      expect(params['limit'], 20);
    });

    test('使用自定义分页参数获取家庭成员位置历史', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenAnswer((_) async => mockResponse({'data': [recordJson]}));

      await service.getFamilyMemberHistory(
        familyId: 'f1',
        memberId: 'u1',
        skip: 5,
        limit: 15,
      );

      final captured = verify(() => mockDio.get(
        '/location/family/f1/member/u1/history',
        queryParameters: captureAny(named: 'queryParameters'),
      )).captured;
      final params = captured.first as Map<String, dynamic>;
      expect(params['skip'], 5);
      expect(params['limit'], 15);
    });
  });
}
