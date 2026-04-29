using CareForTheOld.Common.Constants;
using CareForTheOld.Models.DTOs.Responses;

namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 紧急呼叫服务接口
/// </summary>
public interface IEmergencyService
{
    /// <summary>
    /// 老人发起紧急呼叫
    /// </summary>
    /// <param name="elderId">老人ID</param>
    /// <param name="latitude">纬度（可选）</param>
    /// <param name="longitude">经度（可选）</param>
    /// <param name="batteryLevel">电池电量百分比（可选）</param>
    /// <param name="cancellationToken">取消令牌</param>
    Task<EmergencyCallResponse> CreateCallAsync(Guid elderId, double? latitude = null, double? longitude = null, int? batteryLevel = null, CancellationToken cancellationToken = default);

    /// <summary>
    /// 获取未处理的紧急呼叫（子女端）
    /// </summary>
    Task<List<EmergencyCallResponse>> GetUnreadCallsAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>
    /// 获取历史呼叫记录
    /// </summary>
    Task<List<EmergencyCallResponse>> GetHistoryAsync(Guid userId, int skip = AppConstants.Pagination.DefaultSkip, int limit = AppConstants.Pagination.DefaultHistoryPageSize, CancellationToken cancellationToken = default);

    /// <summary>
    /// 子女标记已处理
    /// </summary>
    Task<EmergencyCallResponse> RespondCallAsync(Guid callId, Guid userId, CancellationToken cancellationToken = default);
}