import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/auth_provider.dart';

/// API 客户端配置
class ApiClient {
  // Android 模拟器使用 10.0.2.2 访问主机服务
  static const String baseUrl = 'http://10.0.2.2:5136/api';

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
        // 从全局状态获取令牌（需要通过 ProviderContainer 获取）
        // 注意：这里使用的是全局 container，在实际应用中应该通过 Provider 传递
        return handler.next(options);
      },
      onError: (error, handler) async {
        // 401 错误时尝试刷新令牌
        if (error.response?.statusCode == 401) {
          // 刷新令牌逻辑需要在 Service 层处理
          // 这里简单地将错误传递下去
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