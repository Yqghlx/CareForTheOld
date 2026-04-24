import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../core/helpers/mock_dio_helper.dart';
import 'package:care_for_the_old_client/features/shared/services/user_service.dart';
import 'package:care_for_the_old_client/shared/models/user.dart';
import 'package:care_for_the_old_client/shared/models/user_role.dart';

void main() {
  late MockDio mockDio;
  late UserService service;

  setUpAll(() => registerFallbackValues());

  setUp(() {
    mockDio = MockDio();
    service = UserService(mockDio);
  });

  /// --- 测试数据常量 ---
  const userJson = {
    'id': 'u1',
    'phoneNumber': '13800000000',
    'realName': '用户',
    'birthDate': '1950-01-01T00:00:00',
    'role': 'Elder',
    'avatarUrl': null,
  };

  // ------------------------------------------------------------------
  // getCurrentUser
  // ------------------------------------------------------------------
  group('getCurrentUser', () {
    test('成功获取当前用户信息', () async {
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => mockResponse({'data': userJson}));

      final result = await service.getCurrentUser();

      expect(result, isA<User>());
      expect(result.id, 'u1');
      expect(result.phoneNumber, '13800000000');
      expect(result.realName, '用户');
      expect(result.role, UserRole.elder);
      expect(result.avatarUrl, isNull);
      verify(() => mockDio.get('/user/me')).called(1);
    });
  });

  // ------------------------------------------------------------------
  // updateUser
  // ------------------------------------------------------------------
  group('updateUser', () {
    test('成功更新用户真实姓名', () async {
      when(() => mockDio.put(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({'data': userJson}));

      final result = await service.updateUser(realName: '新名字');

      expect(result, isA<User>());

      final captured = verify(() => mockDio.put(
        '/user/me',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['realName'], '新名字');
      expect(data.containsKey('avatarUrl'), isFalse);
    });

    test('成功更新用户头像 URL', () async {
      when(() => mockDio.put(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({'data': userJson}));

      final result = await service.updateUser(avatarUrl: 'https://example.com/avatar.jpg');

      expect(result, isA<User>());

      final captured = verify(() => mockDio.put(
        '/user/me',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['avatarUrl'], 'https://example.com/avatar.jpg');
      expect(data.containsKey('realName'), isFalse);
    });

    test('同时更新真实姓名和头像', () async {
      when(() => mockDio.put(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({'data': userJson}));

      await service.updateUser(
        realName: '新名字',
        avatarUrl: 'https://example.com/new.jpg',
      );

      final captured = verify(() => mockDio.put(
        '/user/me',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['realName'], '新名字');
      expect(data['avatarUrl'], 'https://example.com/new.jpg');
    });
  });

  // ------------------------------------------------------------------
  // changePassword
  // ------------------------------------------------------------------
  group('changePassword', () {
    test('密码修改成功返回 true', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({'success': true}));

      final result = await service.changePassword(
        oldPassword: 'old123',
        newPassword: 'new456',
      );

      expect(result, true);

      final captured = verify(() => mockDio.post(
        '/user/me/password',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['oldPassword'], 'old123');
      expect(data['newPassword'], 'new456');
    });

    test('密码修改失败返回 false', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({'success': false}));

      final result = await service.changePassword(
        oldPassword: 'wrong',
        newPassword: 'new456',
      );

      expect(result, false);
    });
  });

  // ------------------------------------------------------------------
  // uploadAvatar
  // ------------------------------------------------------------------
  group('uploadAvatar', () {
    test('成功上传头像并返回头像 URL', () async {
      const avatarUrl = 'https://cdn.example.com/avatars/u1_new.jpg';
      when(() => mockDio.post(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      )).thenAnswer((_) async => mockResponse({
        'data': {'avatarUrl': avatarUrl},
      }));

      // uploadAvatar 内部调用 MultipartFile.fromFile 需要真实文件
      // 因此创建一个临时文件用于测试
      final tempFile = File('${Directory.systemTemp.path}/test_avatar.png');
      await tempFile.writeAsBytes([1, 2, 3, 4]);

      try {
        final result = await service.uploadAvatar(tempFile.path);

        expect(result, avatarUrl);
        verify(() => mockDio.post(
          '/user/me/avatar',
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).called(1);
      } finally {
        // 测试结束后清理临时文件
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    });
  });
}
