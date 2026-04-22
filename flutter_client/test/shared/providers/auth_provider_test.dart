import 'package:flutter_test/flutter_test.dart';
import 'package:care_for_the_old_client/shared/models/user.dart';
import 'package:care_for_the_old_client/shared/models/user_role.dart';
import 'package:care_for_the_old_client/shared/providers/auth_provider.dart';

void main() {
  group('AuthState 认证状态测试', () {
    test('初始状态应为未认证', () {
      const state = AuthState();
      expect(state.isAuthenticated, false);
      expect(state.user, null);
      expect(state.accessToken, null);
      expect(state.refreshToken, null);
      expect(state.role, null);
    });

    test('isElder getter 应正确判断老人角色', () {
      final elderState = AuthState(
        isAuthenticated: true,
        role: UserRole.elder,
      );
      expect(elderState.isElder, true);
      expect(elderState.isChild, false);
    });

    test('isChild getter 应正确判断子女角色', () {
      final childState = AuthState(
        isAuthenticated: true,
        role: UserRole.child,
      );
      expect(childState.isChild, true);
      expect(childState.isElder, false);
    });

    test('无角色时 isElder/isChild 应返回 false', () {
      const state = AuthState(isAuthenticated: true);
      expect(state.isElder, false);
      expect(state.isChild, false);
    });

    test('copyWith 应正确复制并更新状态', () {
      const original = AuthState();
      final updated = original.copyWith(
        isAuthenticated: true,
        accessToken: 'test-token',
        refreshToken: 'refresh-token',
      );

      expect(updated.isAuthenticated, true);
      expect(updated.accessToken, 'test-token');
      expect(updated.refreshToken, 'refresh-token');
      // 未更新的字段保持原值
      expect(updated.user, null);
      expect(updated.role, null);
    });

    test('copyWith 应支持部分更新', () {
      final state = AuthState(
        isAuthenticated: true,
        accessToken: 'original-token',
        role: UserRole.elder,
      );

      final updated = state.copyWith(accessToken: 'new-token');

      expect(updated.isAuthenticated, true); // 保持不变
      expect(updated.accessToken, 'new-token'); // 更新
      expect(updated.role, UserRole.elder); // 保持不变
    });
  });

  group('User 用户模型测试', () {
    test('fromJson 应正确解析用户数据', () {
      final json = {
        'id': 'user-123',
        'phoneNumber': '13800138000',
        'realName': '张三',
        'birthDate': '1950-01-01T00:00:00',
        'role': 'Elder',
        'avatarUrl': 'https://example.com/avatar.jpg',
      };

      final user = User.fromJson(json);

      expect(user.id, 'user-123');
      expect(user.phoneNumber, '13800138000');
      expect(user.realName, '张三');
      expect(user.birthDate, DateTime(1950, 1, 1));
      expect(user.role, UserRole.elder);
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
    });

    test('toJson 应正确序列化用户数据', () {
      final user = User(
        id: 'user-456',
        phoneNumber: '13900139000',
        realName: '李四',
        birthDate: DateTime(1960, 6, 15),
        role: UserRole.child,
        avatarUrl: null,
      );

      final json = user.toJson();

      expect(json['id'], 'user-456');
      expect(json['phoneNumber'], '13900139000');
      expect(json['realName'], '李四');
      expect(json['birthDate'], '1960-06-15T00:00:00.000');
      expect(json['role'], 'child');
      expect(json['avatarUrl'], null);
    });

    test('可选字段缺失时fromJson应正确处理', () {
      final json = {
        'id': 'user-789',
        'phoneNumber': '13700137000',
        'role': 'Elder',
      };

      final user = User.fromJson(json);

      expect(user.id, 'user-789');
      expect(user.phoneNumber, '13700137000');
      expect(user.realName, null);
      expect(user.birthDate, null);
      expect(user.role, UserRole.elder);
      expect(user.avatarUrl, null);
    });
  });
}