import 'package:flutter_test/flutter_test.dart';
import 'package:care_for_the_old_client/shared/models/neighbor_help_request.dart';

void main() {
  group('HelpRequestStatus 枚举测试', () {
    test('fromString 应正确解析已知值', () {
      expect(HelpRequestStatus.fromString('pending'), HelpRequestStatus.pending);
      expect(HelpRequestStatus.fromString('accepted'), HelpRequestStatus.accepted);
      expect(HelpRequestStatus.fromString('cancelled'), HelpRequestStatus.cancelled);
      expect(HelpRequestStatus.fromString('resolved'), HelpRequestStatus.resolved);
      expect(HelpRequestStatus.fromString('expired'), HelpRequestStatus.expired);
    });

    test('fromString 未知值应默认为 pending', () {
      expect(HelpRequestStatus.fromString('unknown'), HelpRequestStatus.pending);
    });
  });

  group('NeighborHelpRequest 模型测试', () {
    test('fromJson 应正确解析完整数据', () {
      final json = {
        'id': 'request-001',
        'emergencyCallId': 'call-001',
        'circleId': 'circle-001',
        'requesterId': 'user-001',
        'requesterName': '张大爷',
        'responderId': 'user-002',
        'responderName': '李阿姨',
        'status': 'accepted',
        'latitude': 39.9042,
        'longitude': 116.4074,
        'requestedAt': '2026-04-20T08:00:00Z',
        'respondedAt': '2026-04-20T08:02:00Z',
        'expiresAt': '2026-04-20T08:15:00Z',
        'distanceMeters': 200.0,
      };

      final request = NeighborHelpRequest.fromJson(json);

      expect(request.id, 'request-001');
      expect(request.emergencyCallId, 'call-001');
      expect(request.circleId, 'circle-001');
      expect(request.requesterId, 'user-001');
      expect(request.requesterName, '张大爷');
      expect(request.responderId, 'user-002');
      expect(request.responderName, '李阿姨');
      expect(request.status, HelpRequestStatus.accepted);
      expect(request.latitude, 39.9042);
      expect(request.longitude, 116.4074);
      expect(request.respondedAt, DateTime.parse('2026-04-20T08:02:00Z'));
      expect(request.expiresAt, DateTime.parse('2026-04-20T08:15:00Z'));
      expect(request.distanceMeters, 200.0);
    });

    test('fromJson 可选字段缺失时应为 null', () {
      final json = {
        'id': 'request-002',
        'emergencyCallId': 'call-002',
        'circleId': 'circle-002',
        'requesterId': 'user-003',
        'requesterName': '王大爷',
        'status': 'pending',
        'requestedAt': '2026-04-20T08:00:00Z',
        'expiresAt': '2026-04-20T08:15:00Z',
      };

      final request = NeighborHelpRequest.fromJson(json);

      expect(request.responderId, isNull);
      expect(request.responderName, isNull);
      expect(request.latitude, isNull);
      expect(request.longitude, isNull);
      expect(request.respondedAt, isNull);
      expect(request.distanceMeters, isNull);
    });
  });

  group('NeighborHelpRating 模型测试', () {
    test('fromJson 应正确解析完整数据', () {
      final json = {
        'id': 'rating-001',
        'helpRequestId': 'request-001',
        'raterId': 'user-001',
        'rateeId': 'user-002',
        'rating': 5,
        'comment': '非常感谢及时帮助！',
        'createdAt': '2026-04-20T09:00:00Z',
      };

      final rating = NeighborHelpRating.fromJson(json);

      expect(rating.id, 'rating-001');
      expect(rating.helpRequestId, 'request-001');
      expect(rating.raterId, 'user-001');
      expect(rating.rateeId, 'user-002');
      expect(rating.rating, 5);
      expect(rating.comment, '非常感谢及时帮助！');
    });

    test('fromJson comment 缺失时应为 null', () {
      final json = {
        'id': 'rating-002',
        'helpRequestId': 'request-002',
        'raterId': 'user-003',
        'rateeId': 'user-004',
        'rating': 4,
        'comment': null,
        'createdAt': '2026-04-20T09:00:00Z',
      };

      final rating = NeighborHelpRating.fromJson(json);

      expect(rating.rating, 4);
      expect(rating.comment, isNull);
    });
  });
}
