import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_role.dart';
import '../models/user.dart';
import '../../features/shared/services/signalr_service.dart';

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

  AuthNotifier(this._ref) : super(const AuthState()) {
    _loadStoredAuth();
  }

  /// 加载本地存储的认证信息
  Future<void> _loadStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    final refreshToken = prefs.getString('refreshToken');
    final roleStr = prefs.getString('userRole');

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', accessToken);
    await prefs.setString('refreshToken', refreshToken);
    await prefs.setString('userRole', user.role.value);
    await prefs.setString('userId', user.id);

    state = AuthState(
      isAuthenticated: true,
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      role: user.role,
    );

    // 登录成功后连接 SignalR
    _connectSignalR();
  }

  /// 登出
  Future<void> logout() async {
    // 登出时断开 SignalR
    await _disconnectSignalR();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('userRole');
    await prefs.remove('userId');

    state = const AuthState();
  }

  /// 连接 SignalR
  void _connectSignalR() {
    try {
      _ref.read(signalrServiceProvider).connect();
    } catch (e) {
      debugPrint('SignalR 连接失败: $e');
    }
  }

  /// 断开 SignalR
  Future<void> _disconnectSignalR() async {
    try {
      await _ref.read(signalrServiceProvider).disconnect();
    } catch (e) {
      debugPrint('SignalR 断开失败: $e');
    }
  }

  /// 更新令牌
  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', accessToken);
    await prefs.setString('refreshToken', refreshToken);

    state = state.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}

/// Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});