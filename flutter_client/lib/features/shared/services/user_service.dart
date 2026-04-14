import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user.dart';
import '../../../core/api/api_client.dart';

/// 用户服务
class UserService {
  final Dio _dio;

  UserService(this._dio);

  /// 获取当前用户信息
  Future<User> getCurrentUser() async {
    final response = await _dio.get('/api/user/me');
    return User.fromJson(response.data['data']);
  }

  /// 更新用户信息
  Future<User> updateUser({String? realName, String? avatarUrl}) async {
    final response = await _dio.put('/api/user/me', data: {
      if (realName != null) 'realName': realName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    return User.fromJson(response.data['data']);
  }

  /// 修改密码
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await _dio.post('/api/user/me/password', data: {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
    return response.data['success'] == true;
  }
}

/// 用户服务 Provider
final userServiceProvider = Provider<UserService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  return UserService(dio);
});