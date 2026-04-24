import 'package:flutter_test/flutter_test.dart';
import 'package:care_for_the_old_client/shared/models/neighbor_circle.dart';
import 'package:care_for_the_old_client/shared/models/user_role.dart';

void main() {
  group('NeighborCircle 模型测试', () {
    test('fromJson 应正确解析完整数据', () {
      final json = {
        'id': 'circle-001',
        'circleName': '阳光小区互助群',
        'centerLatitude': 39.9042,
        'centerLongitude': 116.4074,
        'radiusMeters': 500.0,
        'creatorId': 'user-001',
        'creatorName': '张大爷',
        'inviteCode': '888888',
        'inviteCodeExpiresAt': '2026-05-01T00:00:00Z',
        'memberCount': 15,
        'isActive': true,
        'createdAt': '2026-04-01T10:00:00Z',
        'distanceMeters': 120.5,
      };

      final circle = NeighborCircle.fromJson(json);

      expect(circle.id, 'circle-001');
      expect(circle.circleName, '阳光小区互助群');
      expect(circle.centerLatitude, 39.9042);
      expect(circle.centerLongitude, 116.4074);
      expect(circle.radiusMeters, 500.0);
      expect(circle.creatorId, 'user-001');
      expect(circle.creatorName, '张大爷');
      expect(circle.inviteCode, '888888');
      expect(circle.inviteCodeExpiresAt, DateTime.parse('2026-05-01T00:00:00Z'));
      expect(circle.memberCount, 15);
      expect(circle.isActive, true);
      expect(circle.distanceMeters, 120.5);
    });

    test('fromJson 可选字段缺失时应使用默认值', () {
      final json = {
        'id': 'circle-002',
        'circleName': '测试圈',
        'centerLatitude': 0.0,
        'centerLongitude': 0.0,
        'radiusMeters': 500.0,
        'creatorId': 'user-002',
        'creatorName': '李大妈',
        'inviteCode': '',
        'memberCount': 1,
        'isActive': true,
        'createdAt': '2026-04-01T10:00:00Z',
      };

      final circle = NeighborCircle.fromJson(json);

      expect(circle.inviteCode, '');
      expect(circle.inviteCodeExpiresAt, isNull);
      expect(circle.distanceMeters, isNull);
    });
  });

  group('NeighborCircleMember 模型测试', () {
    test('fromJson 应正确解析完整数据', () {
      final json = {
        'userId': 'user-001',
        'realName': '张大爷',
        'role': 'elder',
        'nickname': '老张',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'joinedAt': '2026-04-01T10:00:00Z',
        'distanceMeters': 50.0,
      };

      final member = NeighborCircleMember.fromJson(json);

      expect(member.userId, 'user-001');
      expect(member.realName, '张大爷');
      expect(member.role, UserRole.elder);
      expect(member.nickname, '老张');
      expect(member.avatarUrl, 'https://example.com/avatar.jpg');
      expect(member.distanceMeters, 50.0);
    });

    test('fromJson 可选字段缺失时应为 null', () {
      final json = {
        'userId': 'user-002',
        'realName': '李小明',
        'role': 'child',
        'joinedAt': '2026-04-01T10:00:00Z',
      };

      final member = NeighborCircleMember.fromJson(json);

      expect(member.nickname, isNull);
      expect(member.avatarUrl, isNull);
      expect(member.distanceMeters, isNull);
    });
  });
}
