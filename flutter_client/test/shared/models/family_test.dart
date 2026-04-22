import 'package:flutter_test/flutter_test.dart';
import 'package:care_for_the_old_client/shared/models/family.dart';
import 'package:care_for_the_old_client/shared/models/user_role.dart';

void main() {
  group('FamilyGroup 模型测试', () {
    test('fromJson 应正确解析完整数据', () {
      final json = {
        'id': 'family-001',
        'familyName': '张家',
        'inviteCode': '123456',
        'members': [
          {
            'userId': 'user-001',
            'realName': '张大爷',
            'role': 'elder',
            'relation': '爷爷',
            'avatarUrl': null,
          },
          {
            'userId': 'user-002',
            'realName': '张小明',
            'role': 'child',
            'relation': '孙子',
            'avatarUrl': 'https://example.com/avatar.jpg',
          },
        ],
      };

      final family = FamilyGroup.fromJson(json);

      expect(family.id, 'family-001');
      expect(family.familyName, '张家');
      expect(family.inviteCode, '123456');
      expect(family.members.length, 2);
      expect(family.members[0].realName, '张大爷');
      expect(family.members[1].realName, '张小明');
    });

    test('fromJson inviteCode 缺失时应默认为空字符串', () {
      final json = {
        'id': 'family-002',
        'familyName': '李家',
        'members': [],
      };

      final family = FamilyGroup.fromJson(json);
      expect(family.inviteCode, '');
      expect(family.members, isEmpty);
    });
  });

  group('FamilyMember 模型测试', () {
    test('fromJson 应正确解析完整数据', () {
      final json = {
        'userId': 'user-001',
        'realName': '张大爷',
        'role': 'elder',
        'relation': '爷爷',
        'avatarUrl': 'https://example.com/avatar.jpg',
      };

      final member = FamilyMember.fromJson(json);

      expect(member.userId, 'user-001');
      expect(member.realName, '张大爷');
      expect(member.role, UserRole.elder);
      expect(member.relation, '爷爷');
      expect(member.avatarUrl, 'https://example.com/avatar.jpg');
    });

    test('fromJson 整数 role 应正确解析', () {
      final json = {
        'userId': 'user-002',
        'realName': '李小明',
        'role': 1,
        'relation': '儿子',
      };

      final member = FamilyMember.fromJson(json);
      expect(member.role, UserRole.child);
      expect(member.avatarUrl, null);
    });

    test('fromJson 角色为子女时应正确解析', () {
      final json = {
        'userId': 'user-003',
        'realName': '王小丽',
        'role': 'child',
        'relation': '女儿',
      };

      final member = FamilyMember.fromJson(json);
      expect(member.role, UserRole.child);
      expect(member.role.isChild, true);
      expect(member.role.isElder, false);
    });
  });
}