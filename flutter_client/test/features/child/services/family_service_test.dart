import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../core/helpers/mock_dio_helper.dart';
import 'package:care_for_the_old_client/features/child/services/family_service.dart';
import 'package:care_for_the_old_client/shared/models/family.dart';
import 'package:care_for_the_old_client/shared/models/user_role.dart';

void main() {
  late MockDio mockDio;
  late FamilyService service;

  setUpAll(() => registerFallbackValues());

  setUp(() {
    mockDio = MockDio();
    service = FamilyService(mockDio);
  });

  /// --- 测试数据常量 ---
  const familyJson = {
    'id': 'f1',
    'familyName': '测试家庭',
    'inviteCode': 'ABC123',
    'members': <Map<String, dynamic>>[],
  };

  const memberJson = {
    'userId': 'u1',
    'realName': '老人',
    'role': 'Elder',
    'relation': '父亲',
    'avatarUrl': null,
  };

  // ------------------------------------------------------------------
  // getMyFamily
  // ------------------------------------------------------------------
  group('getMyFamily', () {
    test('成功获取我的家庭信息', () async {
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => mockResponse({'data': familyJson}));

      final result = await service.getMyFamily();

      expect(result, isNotNull);
      expect(result!.id, 'f1');
      expect(result.familyName, '测试家庭');
      expect(result.inviteCode, 'ABC123');
      verify(() => mockDio.get('/family/me')).called(1);
    });

    test('data 为 null 时返回 null（用户未加入家庭）', () async {
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => mockResponse({'data': null}));

      final result = await service.getMyFamily();

      expect(result, isNull);
    });
  });

  // ------------------------------------------------------------------
  // createFamily
  // ------------------------------------------------------------------
  group('createFamily', () {
    test('成功创建家庭', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({'data': familyJson}));

      final result = await service.createFamily('测试家庭');

      expect(result, isA<FamilyGroup>());
      expect(result.id, 'f1');
      expect(result.familyName, '测试家庭');

      final captured = verify(() => mockDio.post(
        '/family',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['familyName'], '测试家庭');
    });
  });

  // ------------------------------------------------------------------
  // addMember
  // ------------------------------------------------------------------
  group('addMember', () {
    test('添加老人角色成员，role 应转换为 0', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({'data': familyJson}));

      final result = await service.addMember(
        familyId: 'f1',
        phoneNumber: '13800000000',
        role: UserRole.elder,
        relation: '父亲',
      );

      expect(result, isA<FamilyGroup>());

      final captured = verify(() => mockDio.post(
        '/family/f1/members',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['phoneNumber'], '13800000000');
      expect(data['role'], 0);
      expect(data['relation'], '父亲');
    });

    test('添加子女角色成员，role 应转换为 1', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({'data': familyJson}));

      await service.addMember(
        familyId: 'f1',
        phoneNumber: '13900000000',
        role: UserRole.child,
        relation: '女儿',
      );

      final captured = verify(() => mockDio.post(
        '/family/f1/members',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['role'], 1);
      expect(data['relation'], '女儿');
    });
  });

  // ------------------------------------------------------------------
  // getMembers
  // ------------------------------------------------------------------
  group('getMembers', () {
    test('成功获取家庭成员列表', () async {
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => mockResponse({'data': [memberJson]}));

      final result = await service.getMembers('f1');

      expect(result.length, 1);
      expect(result.first.userId, 'u1');
      expect(result.first.realName, '老人');
      expect(result.first.role, UserRole.elder);
      expect(result.first.relation, '父亲');
      verify(() => mockDio.get('/family/f1/members')).called(1);
    });

    test('家庭无成员时返回空列表', () async {
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => mockResponse({'data': <Map<String, dynamic>>[]}));

      final result = await service.getMembers('f1');

      expect(result, isEmpty);
    });
  });

  // ------------------------------------------------------------------
  // removeMember
  // ------------------------------------------------------------------
  group('removeMember', () {
    test('成功移除家庭成员', () async {
      when(() => mockDio.delete(any()))
          .thenAnswer((_) async => mockResponse(null));

      await service.removeMember(familyId: 'f1', userId: 'u1');

      verify(() => mockDio.delete('/family/f1/members/u1')).called(1);
    });
  });

  // ------------------------------------------------------------------
  // joinFamilyByCode
  // ------------------------------------------------------------------
  group('joinFamilyByCode', () {
    test('成功通过邀请码申请加入家庭', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({
            'data': {
              'message': '申请已提交，等待子女审批',
              'familyName': '测试家庭',
              'status': 'pending',
            }
          }));

      final result = await service.joinFamilyByCode(
        inviteCode: 'ABC123',
        relation: '儿子',
      );

      expect(result, isA<JoinFamilyResult>());
      expect(result.familyName, '测试家庭');
      expect(result.status, FamilyMemberStatus.pending);
      expect(result.message, '申请已提交，等待子女审批');

      final captured = verify(() => mockDio.post(
        '/family/join',
        data: captureAny(named: 'data'),
      )).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['inviteCode'], 'ABC123');
      expect(data['relation'], '儿子');
    });
  });

  // ------------------------------------------------------------------
  // refreshInviteCode
  // ------------------------------------------------------------------
  group('refreshInviteCode', () {
    test('成功刷新邀请码', () async {
      final refreshedJson = Map<String, dynamic>.from(familyJson)
        ..['inviteCode'] = 'NEWCODE';

      when(() => mockDio.post(any()))
          .thenAnswer((_) async => mockResponse({'data': refreshedJson}));

      final result = await service.refreshInviteCode('f1');

      expect(result, isA<FamilyGroup>());
      expect(result.inviteCode, 'NEWCODE');
      verify(() => mockDio.post('/family/f1/refresh-code')).called(1);
    });
  });
}
