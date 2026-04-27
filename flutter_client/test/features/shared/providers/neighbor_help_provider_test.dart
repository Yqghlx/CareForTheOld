import 'package:care_for_the_old_client/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:care_for_the_old_client/features/shared/services/neighbor_help_service.dart';
import 'package:care_for_the_old_client/features/shared/providers/neighbor_help_provider.dart';
import 'package:care_for_the_old_client/shared/models/neighbor_help_request.dart';

/// Mock NeighborHelpService
class MockNeighborHelpService extends Mock implements NeighborHelpService {}

void main() {
  late MockNeighborHelpService mockService;
  late NeighborHelpNotifier notifier;

  const testRequestJson = {
    'id': 'req-001',
    'emergencyCallId': 'call-001',
    'circleId': 'circle-001',
    'requesterId': 'user-001',
    'requesterName': '张大爷',
    'responderId': null,
    'responderName': null,
    'status': 'pending',
    'latitude': 39.9042,
    'longitude': 116.4074,
    'requestedAt': '2026-04-24T10:00:00Z',
    'respondedAt': null,
    'expiresAt': '2026-04-24T10:30:00Z',
    'distanceMeters': 200.0,
  };

  const testRatingJson = {
    'id': 'rating-001',
    'helpRequestId': 'req-001',
    'raterId': 'user-001',
    'rateeId': 'user-002',
    'rating': 5,
    'comment': '非常感谢',
    'createdAt': '2026-04-24T11:00:00Z',
  };

  setUp(() {
    mockService = MockNeighborHelpService();
    notifier = NeighborHelpNotifier(mockService);
  });

  group('NeighborHelpNotifier', () {
    group('loadPendingRequests', () {
      test('成功加载待响应列表', () async {
        final request = NeighborHelpRequest.fromJson(testRequestJson);
        when(() => mockService.getPendingRequests())
            .thenAnswer((_) async => [request]);

        await notifier.loadPendingRequests();

        expect(notifier.state.pendingRequests.length, 1);
        expect(notifier.state.hasPendingRequests, isTrue);
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.error, isNull);
      });

      test('无待响应请求时列表为空', () async {
        when(() => mockService.getPendingRequests())
            .thenAnswer((_) async => []);

        await notifier.loadPendingRequests();

        expect(notifier.state.pendingRequests, isEmpty);
        expect(notifier.state.hasPendingRequests, isFalse);
      });

      test('网络错误时记录错误', () async {
        when(() => mockService.getPendingRequests())
            .thenThrow(Exception('网络错误'));

        await notifier.loadPendingRequests();

        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.error, isNotNull);
      });
    });

    group('loadHistory', () {
      test('成功加载互助历史', () async {
        final request = NeighborHelpRequest.fromJson({
          ...testRequestJson,
          'status': 'resolved',
          'responderId': 'user-002',
          'responderName': '李阿姨',
        });
        when(() => mockService.getHistory(
              skip: any(named: 'skip'),
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => [request]);

        await notifier.loadHistory();

        expect(notifier.state.history.length, 1);
        expect(notifier.state.history[0].status, HelpRequestStatus.resolved);
      });
    });

    group('acceptRequest', () {
      test('成功接受求助', () async {
        // 先加载待响应列表
        final request = NeighborHelpRequest.fromJson(testRequestJson);
        when(() => mockService.getPendingRequests())
            .thenAnswer((_) async => [request]);
        await notifier.loadPendingRequests();
        expect(notifier.state.pendingRequests.length, 1);

        // 接受后返回已更新的请求
        final accepted = NeighborHelpRequest.fromJson({
          ...testRequestJson,
          'status': 'accepted',
          'responderId': 'user-002',
          'responderName': '李阿姨',
        });
        when(() => mockService.acceptRequest(any()))
            .thenAnswer((_) async => accepted);
        final success = await notifier.acceptRequest('req-001');

        expect(success, isTrue);
        expect(notifier.state.pendingRequests, isEmpty);
      });

      test('接受失败返回 false', () async {
        when(() => mockService.acceptRequest(any()))
            .thenThrow(Exception('已被他人接受'));

        final success = await notifier.acceptRequest('req-001');

        expect(success, isFalse);
        expect(notifier.state.error, AppTheme.msgOperationFailed);
      });
    });

    group('cancelRequest', () {
      test('成功取消求助', () async {
        when(() => mockService.cancelRequest(any()))
            .thenAnswer((_) async {});

        final success = await notifier.cancelRequest('req-001');

        expect(success, isTrue);
      });

      test('取消失败返回 false', () async {
        when(() => mockService.cancelRequest(any()))
            .thenThrow(Exception('无法取消'));

        final success = await notifier.cancelRequest('req-001');

        expect(success, isFalse);
        expect(notifier.state.error, isNotNull);
      });
    });

    group('rateRequest', () {
      test('成功评价互助', () async {
        final rating = NeighborHelpRating.fromJson(testRatingJson);
        when(() => mockService.rateRequest(
              requestId: any(named: 'requestId'),
              rating: any(named: 'rating'),
              comment: any(named: 'comment'),
            )).thenAnswer((_) async => rating);

        final success = await notifier.rateRequest(
          requestId: 'req-001',
          rating: 5,
          comment: '非常感谢',
        );

        expect(success, isTrue);
      });

      test('评价失败返回 false', () async {
        when(() => mockService.rateRequest(
              requestId: any(named: 'requestId'),
              rating: any(named: 'rating'),
              comment: any(named: 'comment'),
            )).thenThrow(Exception('已评价'));

        final success = await notifier.rateRequest(
          requestId: 'req-001',
          rating: 4,
        );

        expect(success, isFalse);
        expect(notifier.state.error, isNotNull);
      });
    });
  });

  group('NeighborHelpState', () {
    test('初始状态正确', () {
      const state = NeighborHelpState();
      expect(state.pendingRequests, isEmpty);
      expect(state.history, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.hasPendingRequests, isFalse);
    });

    test('copyWith 正确更新字段', () {
      const state = NeighborHelpState();
      final newState = state.copyWith(isLoading: true, error: 'test');
      expect(newState.isLoading, isTrue);
      expect(newState.error, 'test');
    });

    test('copyWith clearError 清除错误', () async {
      final state = const NeighborHelpState().copyWith(error: '错误');
      expect(state.error, '错误');
      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('hasPendingRequests 正确反映列表状态', () {
      const empty = NeighborHelpState();
      expect(empty.hasPendingRequests, isFalse);

      final request = NeighborHelpRequest.fromJson(testRequestJson);
      final withRequests = const NeighborHelpState()
          .copyWith(pendingRequests: [request]);
      expect(withRequests.hasPendingRequests, isTrue);
    });
  });
}
