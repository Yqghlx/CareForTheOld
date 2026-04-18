import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/auth_provider.dart';

/// API 客户端配置
class ApiClient {
  // Android 模拟器通过 10.0.2.2 访问宿主机 localhost
  // 真机部署时改为宿主机局域网 IP（如 192.168.x.x）
  // Docker 部署端口为 5001（macOS AirPlay 占用 5000）
  static const String baseUrl = 'http://10.0.2.2:5001/api';

  late final Dio _dio;

  /// 用于刷新令牌的独立 Dio 实例，避免触发刷新拦截器的递归调用
  late final Dio _refreshDio;

  /// Token 获取回调，由 Provider 注入
  final String? Function()? _tokenGetter;

  /// 刷新令牌获取回调
  final String? Function()? _refreshTokenGetter;

  /// 令牌刷新成功回调，用于通知外部更新存储的令牌
  final Future<void> Function(String newAccessToken, String newRefreshToken)?
      _onTokenRefreshed;

  /// 登出回调，刷新失败时触发
  final void Function()? _onUnauthorized;

  /// 用于防止多个并发请求同时触发刷新
  bool _isRefreshing = false;

  /// 刷新期间排队等待的请求列表
  final List<_RetryRequest> _pendingRequests = [];

  ApiClient({
    String? Function()? tokenGetter,
    String? Function()? refreshTokenGetter,
    Future<void> Function(String newAccessToken, String newRefreshToken)?
        onTokenRefreshed,
    void Function()? onUnauthorized,
  })  : _tokenGetter = tokenGetter,
        _refreshTokenGetter = refreshTokenGetter,
        _onTokenRefreshed = onTokenRefreshed,
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

    // 刷新令牌专用的 Dio 实例，不挂载拦截器
    _refreshDio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
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
        debugPrint(
            'API请求: ${options.path}, Token: ${token != null ? "${token.substring(0, 20)}..." : "null"}');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // 仅处理 401 错误
        if (error.response?.statusCode != 401) {
          return handler.next(error);
        }

        // 排除刷新接口本身的 401，避免无限递归
        if (error.requestOptions.path.contains('/auth/refresh')) {
          debugPrint('刷新令牌接口返回 401，令牌已失效');
          _onUnauthorized?.call();
          _processPendingRequests(refreshed: false);
          return handler.next(error);
        }

        final refreshToken = _refreshTokenGetter?.call();
        if (refreshToken == null || refreshToken.isEmpty) {
          debugPrint('无可用刷新令牌，直接登出');
          _onUnauthorized?.call();
          return handler.next(error);
        }

        // 将当前请求加入等待队列
        final completer = _RetryRequest(error.requestOptions, handler);
        _pendingRequests.add(completer);

        // 如果已有刷新流程正在进行，等待即可
        if (_isRefreshing) {
          debugPrint('令牌刷新进行中，请求排队等待: ${error.requestOptions.path}');
          return;
        }

        // 开始刷新流程
        _isRefreshing = true;
        debugPrint('检测到 401，开始刷新令牌...');

        try {
          final newTokens = await _refreshTokens(refreshToken);
          if (newTokens != null) {
            debugPrint('令牌刷新成功，重试排队请求');
            // 通知外部更新令牌存储
            await _onTokenRefreshed?.call(
                newTokens['accessToken']!, newTokens['refreshToken']!);
            _isRefreshing = false;
            _processPendingRequests(refreshed: true);
          } else {
            debugPrint('令牌刷新失败，执行登出');
            _isRefreshing = false;
            _onUnauthorized?.call();
            _processPendingRequests(refreshed: false);
          }
        } catch (e) {
          debugPrint('令牌刷新异常: $e');
          _isRefreshing = false;
          _onUnauthorized?.call();
          _processPendingRequests(refreshed: false);
        }
      },
    ));
  }

  /// 调用 /auth/refresh 接口刷新令牌
  /// 返回新的 accessToken 和 refreshToken，失败返回 null
  Future<Map<String, String>?> _refreshTokens(String refreshToken) async {
    try {
      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        // 兼容直接返回 Map 或包裹在 data 字段中的情况
        final Map<String, dynamic> tokenData =
            data is Map<String, dynamic> ? data : (data['data'] as Map<String, dynamic>? ?? {});

        final newAccessToken = tokenData['accessToken']?.toString() ??
            tokenData['AccessToken']?.toString();
        final newRefreshToken = tokenData['refreshToken']?.toString() ??
            tokenData['RefreshToken']?.toString();

        if (newAccessToken != null && newRefreshToken != null) {
          return {
            'accessToken': newAccessToken,
            'refreshToken': newRefreshToken,
          };
        }
      }
      return null;
    } on DioException catch (e) {
      debugPrint('刷新令牌请求失败: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('刷新令牌未知异常: $e');
      return null;
    }
  }

  /// 处理排队等待的请求：刷新成功则用新令牌重试，失败则全部拒绝
  void _processPendingRequests({required bool refreshed}) {
    final pending = List<_RetryRequest>.from(_pendingRequests);
    _pendingRequests.clear();

    for (final retry in pending) {
      if (refreshed) {
        // 使用新令牌重发原始请求
        final newToken = _tokenGetter?.call();
        if (newToken != null) {
          retry.options.headers['Authorization'] = 'Bearer $newToken';
        }
        // 利用 Dio 的 fetch 方法重试原始请求
        _dio.fetch(retry.options).then(
          (response) => retry.handler.resolve(response),
          onError: (error) => retry.handler.next(error),
        );
      } else {
        // 刷新失败，传递原始错误
        retry.handler.next(DioException(
          requestOptions: retry.options,
          response: Response(
            requestOptions: retry.options,
            statusCode: 401,
          ),
          message: '令牌刷新失败，请重新登录',
        ));
      }
    }
  }

  Dio get dio => _dio;
}

/// 等待重试的请求封装
class _RetryRequest {
  final RequestOptions options;
  final ErrorInterceptorHandler handler;

  _RetryRequest(this.options, this.handler);
}

/// API 客户端 Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenGetter: () => ref.read(authProvider).accessToken,
    refreshTokenGetter: () => ref.read(authProvider).refreshToken,
    onTokenRefreshed: (newAccessToken, newRefreshToken) async {
      await ref.read(authProvider.notifier).updateTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );
    },
    onUnauthorized: () => ref.read(authProvider.notifier).logout(),
  );
});
