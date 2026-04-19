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
    Task<EmergencyCallResponse> CreateCallAsync(Guid elderId, double? latitude = null, double? longitude = null, int? batteryLevel = null);

    /// <summary>
    /// 获取未处理的紧急呼叫（子女端）
    /// </summary>
    Task<List<EmergencyCallResponse>> GetUnreadCallsAsync(Guid userId);

    /// <summary>
    /// 获取历史呼叫记录
    /// </summary>
    Task<List<EmergencyCallResponse>> GetHistoryAsync(Guid userId, int skip = 0, int limit = 20);

    /// <summary>
    /// 子女标记已处理
    /// </summary>
    Task<EmergencyCallResponse> RespondCallAsync(Guid callId, Guid userId);
}