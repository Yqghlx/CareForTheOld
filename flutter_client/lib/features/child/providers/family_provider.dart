import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../services/family_service.dart';
import '../../../shared/models/family.dart';

/// 家庭服务 Provider
final familyServiceProvider = Provider<FamilyService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  return FamilyService(dio);
});

/// 家庭状态
class FamilyState {
  final FamilyGroup? family;
  final bool isLoading;
  final String? error;

  const FamilyState({
    this.family,
    this.isLoading = false,
    this.error,
  });

  FamilyState copyWith({
    FamilyGroup? family,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FamilyState(
      family: family ?? this.family,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// 家庭ID
  String? get familyId => family?.id;

  /// 老人成员列表
  List<FamilyMember> get elders =>
      family?.members.where((m) => m.role.isElder).toList() ?? [];

  /// 全部成员
  List<FamilyMember> get members => family?.members ?? [];
}

/// 家庭状态 Notifier
class FamilyNotifier extends StateNotifier<FamilyState> {
  final FamilyService _service;

  FamilyNotifier(this._service) : super(const FamilyState());

  /// 加载家庭信息（从 API 获取，不依赖本地缓存）
  Future<void> loadFamily() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final family = await _service.getMyFamily();
      if (family != null) {
        // 保存家庭信息到本地（用于子女端缓存）
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('familyId', family.id);
        await prefs.setString('familyName', family.familyName);
      }
      state = state.copyWith(family: family, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 创建家庭组
  Future<bool> createFamily(String familyName) async {
    try {
      final family = await _service.createFamily(familyName);
      // 保存家庭信息到本地
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('familyId', family.id);
      await prefs.setString('familyName', family.familyName);
      state = state.copyWith(family: family);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 添加家庭成员
  Future<bool> addMember({
    required String phoneNumber,
    required role,
    required String relation,
  }) async {
    final familyId = state.familyId;
    if (familyId == null) return false;
    try {
      final updatedFamily = await _service.addMember(
        familyId: familyId,
        phoneNumber: phoneNumber,
        role: role,
        relation: relation,
      );
      state = state.copyWith(family: updatedFamily);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 移除家庭成员
  Future<bool> removeMember(String userId) async {
    final familyId = state.familyId;
    if (familyId == null) return false;
    try {
      await _service.removeMember(familyId: familyId, userId: userId);
      // 从本地列表中移除
      final updatedMembers =
          state.family!.members.where((m) => m.userId != userId).toList();
      state = state.copyWith(
        family: FamilyGroup(
          id: state.family!.id,
          familyName: state.family!.familyName,
          members: updatedMembers,
        ),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

/// 家庭状态 Provider
final familyProvider =
    StateNotifierProvider<FamilyNotifier, FamilyState>((ref) {
  final service = ref.watch(familyServiceProvider);
  return FamilyNotifier(service);
});
