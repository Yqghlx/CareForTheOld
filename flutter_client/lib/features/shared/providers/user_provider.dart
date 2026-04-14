import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user.dart';
import '../services/user_service.dart';

/// 用户状态
class UserState {
  final User? user;
  final bool isLoading;
  final String? error;

  const UserState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  UserState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return UserState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 用户状态 Notifier
class UserNotifier extends StateNotifier<UserState> {
  final UserService _service;

  UserNotifier(this._service) : super(const UserState());

  /// 加载用户信息
  Future<void> loadUser() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _service.getCurrentUser();
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 更新用户信息
  Future<bool> updateUser({String? realName, String? avatarUrl}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _service.updateUser(
        realName: realName,
        avatarUrl: avatarUrl,
      );
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// 修改密码
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final success = await _service.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// 用户状态 Provider
final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  final service = ref.watch(userServiceProvider);
  return UserNotifier(service);
});