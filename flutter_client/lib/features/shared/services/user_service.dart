import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/api_endpoints.dart';

/// 用户服务
class UserService {
  final Dio _dio;

  UserService(this._dio);

  /// 获取当前用户信息
  Future<User> getCurrentUser() async {
    final response = await _dio.get(ApiEndpoints.userMe);
    return User.fromJson(response.data['data']);
  }

  /// 更新用户信息
  Future<User> updateUser({String? realName, String? avatarUrl}) async {
    final response = await _dio.put(ApiEndpoints.userMe, data: {
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
    final response = await _dio.post(ApiEndpoints.userPassword, data: {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
    return response.data['success'] == true;
  }

  /// 上传头像
  ///
  /// [filePath] 本地图片文件路径。
  /// 返回头像在服务端的相对 URL。
  Future<String> uploadAvatar(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post(
      '/user/me/avatar',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data['data']['avatarUrl'] as String;
  }
}

/// 用户服务 Provider
final userServiceProvider = Provider<UserService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  return UserService(dio);
});