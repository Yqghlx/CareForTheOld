using CareForTheOld.Common.Constants;
using CareForTheOld.Models.DTOs.Requests.Neighbor;
using CareForTheOld.Models.DTOs.Responses;

namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 邻里互助服务接口：求助广播、响应、完成确认、评价
/// </summary>
public interface INeighborHelpService
{
    /// <summary>
    /// 广播求助请求给邻里圈中附近的邻居
    /// 由 EmergencyService.CreateCallAsync 在 Task.Run 中调用
    /// </summary>
    Task BroadcastHelpRequestAsync(Guid emergencyCallId);

    /// <summary>接受求助请求（第一个接受者生效，竞态安全）</summary>
    Task<NeighborHelpRequestResponse> AcceptHelpRequestAsync(Guid requestId, Guid responderId);

    /// <summary>取消求助请求</summary>
    Task CancelHelpRequestAsync(Guid requestId, Guid operatorId);

    /// <summary>评价互助（1-5 星）</summary>
    Task<NeighborHelpRatingResponse> RateHelpRequestAsync(Guid requestId, Guid raterId, RateHelpRequest request);

    /// <summary>获取当前用户待响应的求助列表</summary>
    Task<List<NeighborHelpRequestResponse>> GetPendingRequestsAsync(Guid userId);

    /// <summary>获取互助历史记录</summary>
    Task<List<NeighborHelpRequestResponse>> GetHistoryAsync(Guid userId, int skip = AppConstants.Pagination.DefaultSkip, int limit = AppConstants.Pagination.DefaultHistoryPageSize);

    /// <summary>获取求助请求详情</summary>
    Task<NeighborHelpRequestResponse> GetRequestAsync(Guid requestId);

    /// <summary>清理过期的求助请求（Hangfire 定时调用）</summary>
    Task CleanupExpiredRequestsAsync();
}
