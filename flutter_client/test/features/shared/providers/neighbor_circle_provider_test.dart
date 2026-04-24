import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../core/helpers/mock_dio_helper.dart';
import 'package:care_for_the_old_client/features/shared/services/neighbor_circle_service.dart';
import 'package:care_for_the_old_client/features/shared/providers/neighbor_circle_provider.dart';
import 'package:care_for_the_old_client/shared/models/neighbor_circle.dart';

/// Mock NeighborCircleService
class MockNeighborCircleService extends Mock implements NeighborCircleService {}

void main() {
  late MockNeighborCircleService mockService;
  late NeighborCircleNotifier notifier;

  const testCircleJson = {
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

  final testCircle = NeighborCircle.fromJson(testCircleJson);

  setUp(() {
    mockService = MockNeighborCircleService();
    notifier = NeighborCircleNotifier(mockService);
  });

  group('NeighborCircleNotifier', () {
    group('loadMyCircle', () {
      test('成功加载圈子信息', () async {
        when(() => mockService.getMyCircle())
            .thenAnswer((_) async => testCircle);

        await notifier.loadMyCircle();

        expect(notifier.state.hasCircle, isTrue);
        expect(notifier.state.circle!.circleName, '阳光小区');
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.error, isNull);
      });

      test('未加入圈子时 circle 为 null', () async {
        when(() => mockService.getMyCircle())
            .thenAnswer((_) async => null);

        await notifier.loadMyCircle();

        expect(notifier.state.hasCircle, isFalse);
        expect(notifier.state.circle, isNull);
      });

      test('网络错误时记录错误信息', () async {
        when(() => mockService.getMyCircle())
            .thenThrow(Exception('网络错误'));

        await notifier.loadMyCircle();

        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.error, isNotNull);
        expect(notifier.state.error, contains('网络错误'));
      });
    });

    group('createCircle', () {
      test('成功创建圈子', () async {
        when(() => mockService.createCircle(
              circleName: any(named: 'circleName'),
              centerLatitude: any(named: 'centerLatitude'),
              centerLongitude: any(named: 'centerLongitude'),
            )).thenAnswer((_) async => testCircle);

        final success = await notifier.createCircle(
          circleName: '阳光小区',
          latitude: 39.9042,
          longitude: 116.4074,
        );

        expect(success, isTrue);
        expect(notifier.state.hasCircle, isTrue);
        expect(notifier.state.circle!.circleName, '阳光小区');
      });

      test('创建失败返回 false 并记录错误', () async {
        when(() => mockService.createCircle(
              circleName: any(named: 'circleName'),
              centerLatitude: any(named: 'centerLatitude'),
              centerLongitude: any(named: 'centerLongitude'),
            )).thenThrow(Exception('创建失败'));

        final success = await notifier.createCircle(
          circleName: '测试',
          latitude: 39.9,
          longitude: 116.4,
        );

        expect(success, isFalse);
        expect(notifier.state.error, isNotNull);
      });
    });

    group('joinCircle', () {
      test('成功通过邀请码加入', () async {
        when(() => mockService.joinCircle(any()))
            .thenAnswer((_) async => testCircle);

        final success = await notifier.joinCircle('888888');

        expect(success, isTrue);
        expect(notifier.state.hasCircle, isTrue);
      });

      test('加入失败返回 false', () async {
        when(() => mockService.joinCircle(any()))
            .thenThrow(Exception('邀请码无效'));

        final success = await notifier.joinCircle('000000');

        expect(success, isFalse);
        expect(notifier.state.error, contains('邀请码无效'));
      });
    });

    group('leaveCircle', () {
      test('成功退出圈子', () async {
        // 先加入一个圈子
        when(() => mockService.getMyCircle())
            .thenAnswer((_) async => testCircle);
        await notifier.loadMyCircle();
        expect(notifier.state.hasCircle, isTrue);

        // 退出
        when(() => mockService.leaveCircle(any()))
            .thenAnswer((_) async {});
        final success = await notifier.leaveCircle();

        expect(success, isTrue);
        expect(notifier.state.hasCircle, isFalse);
        expect(notifier.state.members, isEmpty);
      });

      test('未加入圈子时返回 false', () async {
        final success = await notifier.leaveCircle();

        expect(success, isFalse);
      });
    });

    group('searchNearby', () {
      test('成功搜索附近圈子', () async {
        when(() => mockService.searchNearbyCircles(
              latitude: any(named: 'latitude'),
              longitude: any(named: 'longitude'),
              radius: any(named: 'radius'),
            )).thenAnswer((_) async => [testCircle]);

        await notifier.searchNearby(latitude: 39.9, longitude: 116.4);

        expect(notifier.state.nearbyCircles.length, 1);
        expect(notifier.state.nearbyCircles[0].circleName, '阳光小区');
        expect(notifier.state.isLoading, isFalse);
      });

      test('搜索失败时记录错误', () async {
        when(() => mockService.searchNearbyCircles(
              latitude: any(named: 'latitude'),
              longitude: any(named: 'longitude'),
              radius: any(named: 'radius'),
            )).thenThrow(Exception('搜索失败'));

        await notifier.searchNearby(latitude: 39.9, longitude: 116.4);

        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.error, isNotNull);
      });
    });

    group('refreshInviteCode', () {
      test('成功刷新邀请码', () async {
        // 先加入圈子
        when(() => mockService.getMyCircle())
            .thenAnswer((_) async => testCircle);
        await notifier.loadMyCircle();

        final refreshedCircle = NeighborCircle.fromJson({
          ...testCircleJson,
          'inviteCode': '999999',
        });
        when(() => mockService.refreshInviteCode(any()))
            .thenAnswer((_) async => refreshedCircle);

        final success = await notifier.refreshInviteCode();

        expect(success, isTrue);
        expect(notifier.state.circle!.inviteCode, '999999');
      });

      test('未加入圈子时返回 false', () async {
        final success = await notifier.refreshInviteCode();

        expect(success, isFalse);
      });
    });
  });

  group('NeighborCircleState', () {
    test('初始状态正确', () {
      const state = NeighborCircleState();
      expect(state.circle, isNull);
      expect(state.members, isEmpty);
      expect(state.nearbyCircles, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.hasCircle, isFalse);
    });

    test('copyWith 正确更新字段', () {
      const state = NeighborCircleState();
      final newState = state.copyWith(
        circle: testCircle,
        isLoading: true,
        error: 'test',
      );
      expect(newState.circle, testCircle);
      expect(newState.isLoading, isTrue);
      expect(newState.error, 'test');
    });

    test('copyWith clearError 清除错误', () {
      final state = const NeighborCircleState().copyWith(error: '错误');
      expect(state.error, '错误');
      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('copyWith clearCircle 清除圈子', () {
      final state = const NeighborCircleState().copyWith(circle: testCircle);
      expect(state.hasCircle, isTrue);
      final cleared = state.copyWith(clearCircle: true);
      expect(cleared.hasCircle, isFalse);
    });
  });
}
