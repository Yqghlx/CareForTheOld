import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/auth_provider.dart';

/// API 客户端配置
class ApiClient {
  // Android 模拟器使用 10.0.2.2 访问主机服务
  static const String baseUrl = 'http://10.0.2.2:5136/api';

  late final Dio _dio;

  /// Token 获取回调，由 Provider 注入
  final String? Function()? _tokenGetter;

  /// 登出回调，401 时触发
  final void Function()? _onUnauthorized;

  ApiClient({String? Function()? tokenGetter, void Function()? onUnauthorized})
      : _tokenGetter = tokenGetter,
        _onUnauthorized = onUnauthorized {
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
        final token = _tokenGetter?.call();
        // 调试日志
        print('API请求: ${options.path}, Token: ${token != null ? "${token.substring(0, 20)}..." : "null"}');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // 401 错误时清除认证状态，跳转登录页
        if (error.response?.statusCode == 401) {
          _onUnauthorized?.call();
        }
        return handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;
}

/// API 客户端 Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenGetter: () => ref.read(authProvider).accessToken,
    onUnauthorized: () => ref.read(authProvider.notifier).logout(),
  );
});
