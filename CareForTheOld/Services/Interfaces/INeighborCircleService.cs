using CareForTheOld.Models.DTOs.Requests.Neighbor;
using CareForTheOld.Models.DTOs.Responses;

namespace CareForTheOld.Services.Interfaces;

public interface INeighborCircleService
{
    /// <summary>创建邻里圈，创建者自动加入</summary>
    Task<NeighborCircleResponse> CreateCircleAsync(Guid creatorId, CreateNeighborCircleRequest request);

    /// <summary>获取当前用户加入的邻里圈</summary>
    Task<NeighborCircleResponse?> GetMyCircleAsync(Guid userId);

    /// <summary>获取邻里圈详情</summary>
    Task<NeighborCircleResponse> GetCircleAsync(Guid circleId);

    /// <summary>通过邀请码加入邻里圈</summary>
    Task<NeighborCircleResponse> JoinCircleByCodeAsync(Guid userId, JoinNeighborCircleRequest request);

    /// <summary>退出邻里圈（创建者退出则解散）</summary>
    Task LeaveCircleAsync(Guid circleId, Guid userId);

    /// <summary>获取邻里圈成员列表</summary>
    Task<List<NeighborMemberResponse>> GetMembersAsync(Guid circleId);

    /// <summary>获取附近成员（基于最近位置记录）</summary>
    Task<List<NeighborMemberResponse>> GetNearbyMembersAsync(Guid circleId, double latitude, double longitude, double radiusMeters = 500);

    /// <summary>搜索附近的邻里圈</summary>
    Task<List<NeighborCircleResponse>> SearchNearbyCirclesAsync(double latitude, double longitude, double radiusMeters = 2000);

    /// <summary>刷新邀请码（仅创建者可操作）</summary>
    Task<NeighborCircleResponse> RefreshInviteCodeAsync(Guid circleId, Guid operatorId);

    /// <summary>验证操作者是指定邻里圈成员，否则抛出 UnauthorizedAccessException</summary>
    Task EnsureCircleMemberAsync(Guid circleId, Guid userId);
}
