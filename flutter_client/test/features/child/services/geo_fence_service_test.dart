import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../core/helpers/mock_dio_helper.dart';
import 'package:care_for_the_old_client/features/child/services/geo_fence_service.dart';
import 'package:care_for_the_old_client/shared/models/geo_fence.dart';

void main() {
  late MockDio mockDio;
  late GeoFenceService service;

  setUpAll(() => registerFallbackValues());

  setUp(() {
    mockDio = MockDio();
    service = GeoFenceService(mockDio);
  });

  /// --- 测试数据常量 ---
  /// 注意：GeoFence.fromJson 直接从 response.data 解析（非 response.data['data']）
  /// 且包含 createdBy 必填字段
  const fenceJson = {
    'id': 'gf1',
    'elderId': 'e1',
    'elderName': '张大爷',
    'centerLatitude': 39.9,
    'centerLongitude': 116.3,
    'radius': 500,
    'isEnabled': true,
    'createdBy': 'u1',
    'createdAt': '2026-01-01T00:00:00Z',
    'updatedAt': '2026-01-01T00:00:00Z',
  };

  // ------------------------------------------------------------------
  // createFence
  // ------------------------------------------------------------------
  group('createFence', () {
    test('使用默认参数创建电子围栏', () async {
      // createFence 直接从 response.data 解析，不经过 response.data['data']
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse(fenceJson));

      final result = await service.createFence(
        elderId: 'e1',
        centerLatitude: 39.9,
        centerLongitude: 116.3,
      );

      expect(result, isA<GeoFence>());
      expect(result.id, 'gf1');
      expect(result.elderId, 'e1');
      expect(result.centerLatitude, 39.9);
      expect(result.centerLongitude, 116.3);
      expect(result.radius, 500);
      expect(result.isEnabled, true);

      final captured = verify(() => mockDio.post(
        '/geofence',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['elderId'], 'e1');
      expect(data['centerLatitude'], 39.9);
      expect(data['centerLongitude'], 116.3);
      expect(data['radius'], 500);
      expect(data['isEnabled'], true);
    });

    test('使用自定义参数创建电子围栏', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse(fenceJson));

      await service.createFence(
        elderId: 'e1',
        centerLatitude: 40.0,
        centerLongitude: 117.0,
        radius: 1000,
        isEnabled: false,
      );

      final captured = verify(() => mockDio.post(
        '/geofence',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['radius'], 1000);
      expect(data['isEnabled'], false);
    });
  });

  // ------------------------------------------------------------------
  // getElderFence
  // ------------------------------------------------------------------
  group('getElderFence', () {
    test('成功获取老人的电子围栏', () async {
      // getElderFence 直接从 response.data 解析
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => mockResponse(fenceJson));

      final result = await service.getElderFence('e1');

      expect(result, isNotNull);
      expect(result!.id, 'gf1');
      expect(result.elderId, 'e1');
      verify(() => mockDio.get('/geofence/elder/e1')).called(1);
    });

    test('response.data 为 null 时返回 null', () async {
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => mockResponse(null));

      final result = await service.getElderFence('e1');

      expect(result, isNull);
    });

    test('404 错误时捕获异常并返回 null', () async {
      when(() => mockDio.get(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/geofence/elder/e1'),
          response: Response(
            statusCode: 404,
            requestOptions: RequestOptions(path: '/geofence/elder/e1'),
            statusMessage: '404 Not Found',
          ),
          message: 'Http 404 error',
          type: DioExceptionType.badResponse,
        ),
      );

      final result = await service.getElderFence('e1');

      expect(result, isNull);
    });

    test('非 404 错误时应向上抛出异常', () async {
      when(() => mockDio.get(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/geofence/elder/e1'),
          response: Response(
            statusCode: 500,
            requestOptions: RequestOptions(path: '/geofence/elder/e1'),
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        () => service.getElderFence('e1'),
        throwsA(isA<DioException>()),
      );
    });
  });

  // ------------------------------------------------------------------
  // updateFence
  // ------------------------------------------------------------------
  group('updateFence', () {
    test('成功更新电子围栏', () async {
      when(() => mockDio.put(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse(fenceJson));

      final result = await service.updateFence(
        fenceId: 'gf1',
        elderId: 'e1',
        centerLatitude: 39.91,
        centerLongitude: 116.31,
        radius: 800,
        isEnabled: false,
      );

      expect(result, isA<GeoFence>());

      final captured = verify(() => mockDio.put(
        '/geofence/gf1',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['elderId'], 'e1');
      expect(data['centerLatitude'], 39.91);
      expect(data['centerLongitude'], 116.31);
      expect(data['radius'], 800);
      expect(data['isEnabled'], false);
    });

    test('使用默认参数更新电子围栏', () async {
      when(() => mockDio.put(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse(fenceJson));

      await service.updateFence(
        fenceId: 'gf1',
        elderId: 'e1',
        centerLatitude: 39.9,
        centerLongitude: 116.3,
      );

      final captured = verify(() => mockDio.put(
        '/geofence/gf1',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['radius'], 500);
      expect(data['isEnabled'], true);
    });
  });

  // ------------------------------------------------------------------
  // deleteFence
  // ------------------------------------------------------------------
  group('deleteFence', () {
    test('成功删除电子围栏', () async {
      when(() => mockDio.delete(any()))
          .thenAnswer((_) async => mockResponse(null));

      await service.deleteFence('gf1');

      verify(() => mockDio.delete('/geofence/gf1')).called(1);
    });
  });
}
