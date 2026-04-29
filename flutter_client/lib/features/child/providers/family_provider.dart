import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/pref_keys.dart';
import '../services/family_service.dart';
import '../../../shared/models/family.dart';
import '../../../core/extensions/api_error_extension.dart';

/// 家庭服务 Provider
final familyServiceProvider = Provider<FamilyService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  return FamilyService(dio);
});

/// 家庭状态
class FamilyState {
  final FamilyGroup? family;
  final List<FamilyMember> pendingMembers;
  final bool isLoading;
  final String? error;

  const FamilyState({
    this.family,
    this.pendingMembers = const [],
    this.isLoading = false,
    this.error,
  });

  FamilyState copyWith({
    FamilyGroup? family,
    List<FamilyMember>? pendingMembers,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FamilyState(
      family: family ?? this.family,
      pendingMembers: pendingMembers ?? this.pendingMembers,
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

  /// 待审批成员数量
  int get pendingCount => pendingMembers.length;
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
      if (!mounted) return;
      if (family != null) {
        // 保存家庭信息到本地（用于子女端缓存）
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(PrefKeys.familyId, family.id);
        await prefs.setString(PrefKeys.familyName, family.familyName);
      }
      state = state.copyWith(family: family, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: errorMessageFrom(e));
    }
  }

  /// 创建家庭组
  Future<bool> createFamily(String familyName) async {
    state = state.copyWith(clearError: true);
    try {
      final family = await _service.createFamily(familyName);
      if (!mounted) return false;
      // 保存家庭信息到本地
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefKeys.familyId, family.id);
      await prefs.setString(PrefKeys.familyName, family.familyName);
      state = state.copyWith(family: family);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(error: errorMessageFrom(e));
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
      if (!mounted) return false;
      state = state.copyWith(family: updatedFamily);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(error: errorMessageFrom(e));
      return false;
    }
  }

  /// 移除家庭成员
  Future<bool> removeMember(String userId) async {
    final familyId = state.familyId;
    if (familyId == null) return false;
    try {
      await _service.removeMember(familyId: familyId, userId: userId);
      if (!mounted) return false;
      // 从本地列表中移除
      final updatedMembers =
          state.family!.members.where((m) => m.userId != userId).toList();
      state = state.copyWith(
        family: FamilyGroup(
          id: state.family!.id,
          familyName: state.family!.familyName,
          inviteCode: state.family!.inviteCode,
          members: updatedMembers,
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(error: errorMessageFrom(e));
      return false;
    }
  }

  /// 通过邀请码申请加入家庭（申请模式，返回申请结果）
  Future<JoinFamilyResult?> joinFamily({
    required String inviteCode,
    required String relation,
  }) async {
    try {
      final result = await _service.joinFamilyByCode(
        inviteCode: inviteCode,
        relation: relation,
      );
      return result;
    } catch (e) {
      if (!mounted) return null;
      state = state.copyWith(error: errorMessageFrom(e));
      return null;
    }
  }

  /// 刷新邀请码
  Future<bool> refreshInviteCode() async {
    final familyId = state.familyId;
    if (familyId == null) return false;
    try {
      final family = await _service.refreshInviteCode(familyId);
      if (!mounted) return false;
      state = state.copyWith(family: family);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(error: errorMessageFrom(e));
      return false;
    }
  }

  /// 加载待审批成员列表
  Future<void> loadPendingMembers() async {
    final familyId = state.familyId;
    if (familyId == null) return;
    try {
      final pending = await _service.getPendingMembers(familyId);
      if (!mounted) return;
      state = state.copyWith(pendingMembers: pending);
    } catch (_) {
      // 静默失败，不影响主流程
    }
  }

  /// 审批通过成员加入
  Future<bool> approveMember(String memberId) async {
    final familyId = state.familyId;
    if (familyId == null) return false;
    try {
      await _service.approveMember(familyId: familyId, memberId: memberId);
      if (!mounted) return false;
      // 刷新待审批列表和家庭信息
      await loadPendingMembers();
      await loadFamily();
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(error: errorMessageFrom(e));
      return false;
    }
  }

  /// 拒绝成员加入申请
  Future<bool> rejectMember(String memberId) async {
    final familyId = state.familyId;
    if (familyId == null) return false;
    try {
      await _service.rejectMember(familyId: familyId, memberId: memberId);
      if (!mounted) return false;
      // 刷新待审批列表
      await loadPendingMembers();
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(error: errorMessageFrom(e));
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
