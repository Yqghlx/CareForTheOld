import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_role.dart';
import '../models/user.dart';
import '../../features/shared/services/signalr_service.dart';
import '../../core/services/fcm_service.dart';
import '../../core/constants/pref_keys.dart';
import '../../core/services/app_logger.dart';

/// 认证状态
class AuthState {
  final bool isAuthenticated;
  final User? user;
  final String? accessToken;
  final String? refreshToken;
  final UserRole? role;

  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.role,
  });

  bool get isElder => role == UserRole.elder;
  bool get isChild => role == UserRole.child;

  AuthState copyWith({
    bool? isAuthenticated,
    User? user,
    String? accessToken,
    String? refreshToken,
    UserRole? role,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      role: role ?? this.role,
    );
  }
}

/// 认证 Provider
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  /// 安全存储实例，用于加密保存 Token 等敏感信息
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  AuthNotifier(this._ref) : super(const AuthState()) {
    _loadStoredAuth();
  }

  /// 加载本地存储的认证信息
  Future<void> _loadStoredAuth() async {
    // Token 从加密存储读取
    final accessToken = await _secureStorage.read(key: 'accessToken');
    final refreshToken = await _secureStorage.read(key: 'refreshToken');
    // 非敏感信息从 SharedPreferences 读取
    final prefs = await SharedPreferences.getInstance();
    final roleStr = prefs.getString(PrefKeys.userRole);

    if (accessToken != null && refreshToken != null) {
      state = state.copyWith(
        isAuthenticated: true,
        accessToken: accessToken,
        refreshToken: refreshToken,
        role: roleStr != null ? UserRole.fromString(roleStr) : null,
      );

      // 已登录状态自动连接 SignalR
      _connectSignalR();
    }
  }

  /// 登录成功后更新状态
  Future<void> login({
    required User user,
    required String accessToken,
    required String refreshToken,
  }) async {
    // Token 加密存储
    await _secureStorage.write(key: 'accessToken', value: accessToken);
    await _secureStorage.write(key: 'refreshToken', value: refreshToken);
    // 非敏感信息普通存储
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.userRole, user.role.value);
    await prefs.setString(PrefKeys.userId, user.id);

    state = AuthState(
      isAuthenticated: true,
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      role: user.role,
    );

    // 登录成功后连接 SignalR
    _connectSignalR();

    // 登录成功后注册 FCM 推送 token
    _registerFcmToken();

    // 设置 Sentry 用户上下文（便于错误追踪时定位用户）
    Sentry.configureScope((scope) {
      scope.setUser(SentryUser(id: user.id, username: user.realName));
    });
  }

  /// 登出
  Future<void> logout() async {
    // 登出时断开 SignalR
    await _disconnectSignalR();

    // 登出时清除 FCM 推送 token
    await _unregisterFcmToken();

    // 清除加密存储中的 Token
    await _secureStorage.delete(key: 'accessToken');
    await _secureStorage.delete(key: 'refreshToken');
    // 清除非敏感信息
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefKeys.userRole);
    await prefs.remove(PrefKeys.userId);

    // 清除 Sentry 用户上下文
    Sentry.configureScope((scope) => scope.setUser(null));

    state = const AuthState();
  }

  /// 连接 SignalR
  void _connectSignalR() {
    try {
      _ref.read(signalrServiceProvider).connect();
    } catch (e) {
      AppLogger.warning('SignalR 连接失败: $e');
    }
  }

  /// 断开 SignalR
  Future<void> _disconnectSignalR() async {
    try {
      await _ref.read(signalrServiceProvider).disconnect();
    } catch (e) {
      AppLogger.warning('SignalR 断开失败: $e');
    }
  }

  /// 更新令牌（Token 刷新后调用）
  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(key: 'accessToken', value: accessToken);
    await _secureStorage.write(key: 'refreshToken', value: refreshToken);

    state = state.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  /// 注册 FCM 推送 token 到后端
  void _registerFcmToken() {
    try {
      _ref.read(fcmServiceProvider).registerTokenToBackend();
    } catch (e) {
      AppLogger.warning('FCM token 注册失败: $e');
    }
  }

  /// 从后端清除 FCM 推送 token
  Future<void> _unregisterFcmToken() async {
    try {
      await _ref.read(fcmServiceProvider).unregisterTokenFromBackend();
    } catch (e) {
      AppLogger.warning('FCM token 清除失败: $e');
    }
  }
}

/// Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});