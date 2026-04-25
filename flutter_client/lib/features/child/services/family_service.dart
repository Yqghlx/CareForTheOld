import 'package:dio/dio.dart';
import '../../../shared/models/family.dart';
import '../../../shared/models/user_role.dart';

/// 家庭管理 API 服务类
class FamilyService {
  final Dio _dio;

  FamilyService(this._dio);

  /// 获取当前用户所属的家庭信息
  Future<FamilyGroup?> getMyFamily() async {
    final response = await _dio.get('/family/me');
    final data = response.data['data'];
    if (data == null) return null;
    return FamilyGroup.fromJson(data);
  }

  /// 创建家庭组
  Future<FamilyGroup> createFamily(String familyName) async {
    final response = await _dio.post('/family', data: {
      'familyName': familyName,
    });
    final data = response.data['data'];
    return FamilyGroup.fromJson(data);
  }

  /// 添加家庭成员（通过手机号邀请）
  Future<FamilyGroup> addMember({
    required String familyId,
    required String phoneNumber,
    required UserRole role,
    required String relation,
  }) async {
    final response = await _dio.post('/family/$familyId/members', data: {
      'phoneNumber': phoneNumber,
      'role': role == UserRole.elder ? 0 : 1,
      'relation': relation,
    });
    final data = response.data['data'];
    return FamilyGroup.fromJson(data);
  }

  /// 获取家庭成员列表
  Future<List<FamilyMember>> getMembers(String familyId) async {
    final response = await _dio.get('/family/$familyId/members');
    final List<dynamic> dataList = response.data['data'];
    return dataList
        .map((json) => FamilyMember.fromJson(json))
        .toList();
  }

  /// 移除家庭成员
  Future<void> removeMember({
    required String familyId,
    required String userId,
  }) async {
    await _dio.delete('/family/$familyId/members/$userId');
  }

  /// 通过邀请码申请加入家庭
  Future<JoinFamilyResult> joinFamilyByCode({
    required String inviteCode,
    required String relation,
  }) async {
    final response = await _dio.post('/family/join', data: {
      'inviteCode': inviteCode,
      'relation': relation,
    });
    final data = response.data['data'];
    return JoinFamilyResult.fromJson(data);
  }

  /// 刷新邀请码
  Future<FamilyGroup> refreshInviteCode(String familyId) async {
    final response = await _dio.post('/family/$familyId/refresh-code');
    final data = response.data['data'];
    return FamilyGroup.fromJson(data);
  }

  /// 获取待审批成员列表
  Future<List<FamilyMember>> getPendingMembers(String familyId) async {
    final response = await _dio.get('/family/$familyId/pending-members');
    final List<dynamic> dataList = response.data['data'];
    return dataList
        .map((json) => FamilyMember.fromJson(json))
        .toList();
  }

  /// 审批通过成员加入
  Future<void> approveMember({
    required String familyId,
    required String memberId,
  }) async {
    await _dio.post('/family/$familyId/members/$memberId/approve');
  }

  /// 拒绝成员加入申请
  Future<void> rejectMember({
    required String familyId,
    required String memberId,
  }) async {
    await _dio.post('/family/$familyId/members/$memberId/reject');
  }
}
