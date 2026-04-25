using CareForTheOld.Models.DTOs.Requests.Families;
using CareForTheOld.Models.DTOs.Responses;

namespace CareForTheOld.Services.Interfaces;

public interface IFamilyService
{
    Task<FamilyResponse?> GetMyFamilyAsync(Guid userId);
    Task<FamilyResponse> CreateFamilyAsync(Guid creatorId, CreateFamilyRequest request);
    Task<FamilyResponse> AddMemberAsync(Guid familyId, Guid operatorId, AddFamilyMemberRequest request);
    Task<JoinFamilyResponse> JoinFamilyByCodeAsync(Guid userId, JoinFamilyRequest request);
    Task<FamilyResponse> RefreshInviteCodeAsync(Guid familyId, Guid operatorId);
    Task<List<FamilyMemberResponse>> GetMembersAsync(Guid familyId);
    Task RemoveMemberAsync(Guid familyId, Guid userId, Guid operatorId);

    /// <summary>
    /// 获取待审批成员列表（仅子女可查看）
    /// </summary>
    Task<List<FamilyMemberResponse>> GetPendingMembersAsync(Guid familyId, Guid operatorId);

    /// <summary>
    /// 审批通过成员加入（仅子女可操作）
    /// </summary>
    Task ApproveMemberAsync(Guid familyId, Guid memberId, Guid operatorId);

    /// <summary>
    /// 拒绝成员加入申请（仅子女可操作）
    /// </summary>
    Task RejectMemberAsync(Guid familyId, Guid memberId, Guid operatorId);

    /// <summary>
    /// 验证操作者是老人的家庭成员，否则抛出 UnauthorizedAccessException
    /// 老人本人操作时自动通过验证
    /// </summary>
    Task EnsureFamilyMemberAsync(Guid elderId, Guid operatorId);
}
