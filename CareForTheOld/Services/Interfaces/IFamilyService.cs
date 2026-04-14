using CareForTheOld.Models.DTOs.Requests.Families;
using CareForTheOld.Models.DTOs.Responses;

namespace CareForTheOld.Services.Interfaces;

public interface IFamilyService
{
    Task<FamilyResponse?> GetMyFamilyAsync(Guid userId);
    Task<FamilyResponse> CreateFamilyAsync(Guid creatorId, CreateFamilyRequest request);
    Task<FamilyResponse> AddMemberAsync(Guid familyId, Guid operatorId, AddFamilyMemberRequest request);
    Task<FamilyResponse> JoinFamilyByCodeAsync(Guid userId, JoinFamilyRequest request);
    Task<FamilyResponse> RefreshInviteCodeAsync(Guid familyId, Guid operatorId);
    Task<List<FamilyMemberResponse>> GetMembersAsync(Guid familyId);
    Task RemoveMemberAsync(Guid familyId, Guid userId, Guid operatorId);
}