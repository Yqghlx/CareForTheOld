import 'package:dio/dio.dart';
import '../providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// API 客户端配置
class ApiClient {
  static const String baseUrl = 'http://localhost:5000/api';

  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // 请求拦截器 - 添加认证令牌
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 从全局状态获取令牌
        final authState = ProviderScope.containerOf(null!).read(authProvider);
        if (authState.accessToken != null) {
          options.headers['Authorization'] = 'Bearer ${authState.accessToken}';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // 401 错误时尝试刷新令牌
        if (error.response?.statusCode == 401) {
          final authState = ProviderScope.containerOf(null!).read(authProvider);
          if (authState.refreshToken != null) {
            try {
              final response = await _dio.post('/auth/refresh', data: {
                'token': authState.refreshToken,
              });

              final newAccessToken = response.data['data']['accessToken'];
              final newRefreshToken = response.data['data']['refreshToken'];

              // 更新令牌
              ProviderScope.containerOf(null!).read(authProvider.notifier).updateTokens(
                accessToken: newAccessToken,
                refreshToken: newRefreshToken,
              );

              // 重试原请求
              options.headers['Authorization'] = 'Bearer $newAccessToken';
              return handler.resolve(await _dio.fetch(options));
            } catch (_) {
              // 刷新失败，登出
              ProviderScope.containerOf(null!).read(authProvider.notifier).logout();
            }
          }
        }
        return handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;
}

/// API 客户端 Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});