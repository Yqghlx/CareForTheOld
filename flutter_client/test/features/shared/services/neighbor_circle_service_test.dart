import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../core/helpers/mock_dio_helper.dart';
import 'package:care_for_the_old_client/features/shared/services/neighbor_circle_service.dart';
import 'package:care_for_the_old_client/shared/models/neighbor_circle.dart';

void main() {
  late MockDio mockDio;
  late NeighborCircleService service;

  setUpAll(() => registerFallbackValues());

  setUp(() {
    mockDio = MockDio();
    service = NeighborCircleService(mockDio);
  });

  const circleJson = {
    'id': 'circle-001',
    'circleName': '阳光小区',
    'centerLatitude': 39.9042,
    'centerLongitude': 116.4074,
    'radiusMeters': 500.0,
    'creatorId': 'user-001',
    'creatorName': '张大爷',
    'inviteCode': '888888',
    'inviteCodeExpiresAt': null,
    'memberCount': 10,
    'isActive': true,
    'createdAt': '2026-04-01T10:00:00Z',
    'distanceMeters': null,
  };

  group('getMyCircle', () {
    test('成功获取当前用户圈子', () async {
      when(() => mockDio.get('/neighborcircle/me'))
          .thenAnswer((_) async => mockResponse({'data': circleJson}));

      final result = await service.getMyCircle();

      expect(result, isNotNull);
      expect(result!.circleName, '阳光小区');
      expect(result.memberCount, 10);
      verify(() => mockDio.get('/neighborcircle/me')).called(1);
    });

    test('未加入圈子应返回 null', () async {
      when(() => mockDio.get('/neighborcircle/me'))
          .thenAnswer((_) async => mockResponse({'data': null}));

      final result = await service.getMyCircle();

      expect(result, isNull);
    });
  });

  group('createCircle', () {
    test('成功创建圈子', () async {
      when(() => mockDio.post('/neighborcircle', data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({'data': circleJson}));

      final result = await service.createCircle(
        circleName: '阳光小区',
        centerLatitude: 39.9042,
        centerLongitude: 116.4074,
      );

      expect(result.circleName, '阳光小区');
      verify(() => mockDio.post('/neighborcircle', data: any(named: 'data'))).called(1);
    });
  });

  group('joinCircle', () {
    test('成功通过邀请码加入', () async {
      when(() => mockDio.post('/neighborcircle/join', data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({'data': circleJson}));

      final result = await service.joinCircle('888888');

      expect(result.circleName, '阳光小区');
      verify(() => mockDio.post('/neighborcircle/join', data: any(named: 'data'))).called(1);
    });
  });

  group('leaveCircle', () {
    test('成功退出圈子', () async {
      when(() => mockDio.post('/neighborcircle/circle-001/leave'))
          .thenAnswer((_) async => mockResponse({'data': null}));

      await service.leaveCircle('circle-001');

      verify(() => mockDio.post('/neighborcircle/circle-001/leave')).called(1);
    });
  });

  group('getMembers', () {
    test('成功获取成员列表', () async {
      when(() => mockDio.get('/neighborcircle/circle-001/members'))
          .thenAnswer((_) async => mockResponse({
                'data': [
                  {
                    'userId': 'user-001',
                    'realName': '张大爷',
                    'role': 'elder',
                    'nickname': null,
                    'avatarUrl': null,
                    'joinedAt': '2026-04-01T10:00:00Z',
                  },
                ],
              }));

      final result = await service.getMembers('circle-001');

      expect(result.length, 1);
      expect(result[0].realName, '张大爷');
    });
  });

  group('searchNearbyCircles', () {
    test('成功搜索附近圈子', () async {
      when(() => mockDio.get(
            '/neighborcircle/nearby',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => mockResponse({
                'data': [circleJson],
              }));

      final result = await service.searchNearbyCircles(
        latitude: 39.9,
        longitude: 116.4,
      );

      expect(result.length, 1);
      expect(result[0].circleName, '阳光小区');
    });
  });
}
