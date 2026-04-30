using CareForTheOld.Models.DTOs.Requests.Families;
using CareForTheOld.Models.DTOs.Responses;

namespace CareForTheOld.Services.Interfaces;

public interface IFamilyService
{
    /// <summary>获取用户所属的家庭信息（仅返回已通过审批的成员）</summary>
    Task<FamilyResponse?> GetMyFamilyAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>创建家庭组（仅子女角色可创建）</summary>
    Task<FamilyResponse> CreateFamilyAsync(Guid creatorId, CreateFamilyRequest request, CancellationToken cancellationToken = default);

    /// <summary>直接添加家庭成员（子女操作，默认通过审批）</summary>
    Task<FamilyResponse> AddMemberAsync(Guid familyId, Guid operatorId, AddFamilyMemberRequest request, CancellationToken cancellationToken = default);

    /// <summary>通过邀请码申请加入家庭（需子女审批）</summary>
    Task<JoinFamilyResponse> JoinFamilyByCodeAsync(Guid userId, JoinFamilyRequest request, CancellationToken cancellationToken = default);

    /// <summary>刷新家庭邀请码（仅创建者可操作）</summary>
    Task<FamilyResponse> RefreshInviteCodeAsync(Guid familyId, Guid operatorId, CancellationToken cancellationToken = default);

    /// <summary>获取家庭成员列表（仅返回已通过审批的成员）</summary>
    Task<List<FamilyMemberResponse>> GetMembersAsync(Guid familyId, CancellationToken cancellationToken = default);

    /// <summary>移除家庭成员（仅创建者可操作，不可移除自己）</summary>
    Task RemoveMemberAsync(Guid familyId, Guid userId, Guid operatorId, CancellationToken cancellationToken = default);

    /// <summary>
    /// 获取待审批成员列表（仅子女可查看）
    /// </summary>
    Task<List<FamilyMemberResponse>> GetPendingMembersAsync(Guid familyId, Guid operatorId, CancellationToken cancellationToken = default);

    /// <summary>
    /// 审批通过成员加入（仅子女可操作）
    /// </summary>
    Task ApproveMemberAsync(Guid familyId, Guid memberId, Guid operatorId, CancellationToken cancellationToken = default);

    /// <summary>
    /// 拒绝成员加入申请（仅子女可操作）
    /// </summary>
    Task RejectMemberAsync(Guid familyId, Guid memberId, Guid operatorId, CancellationToken cancellationToken = default);

    /// <summary>
    /// 验证操作者是老人的家庭成员，否则抛出 UnauthorizedAccessException
    /// 老人本人操作时自动通过验证
    /// </summary>
    Task EnsureFamilyMemberAsync(Guid elderId, Guid operatorId, CancellationToken cancellationToken = default);

    /// <summary>
    /// 获取指定家庭中所有已通过审批的子女用户 ID
    /// </summary>
    Task<List<Guid>> GetChildUserIdsAsync(Guid familyId, CancellationToken cancellationToken = default);
}
