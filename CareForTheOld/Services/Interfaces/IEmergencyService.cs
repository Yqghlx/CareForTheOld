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
    Task<EmergencyCallResponse> CreateCallAsync(Guid elderId);

    /// <summary>
    /// 获取未处理的紧急呼叫（子女端）
    /// </summary>
    Task<List<EmergencyCallResponse>> GetUnreadCallsAsync(Guid userId);

    /// <summary>
    /// 获取历史呼叫记录
    /// </summary>
    Task<List<EmergencyCallResponse>> GetHistoryAsync(Guid userId, int limit = 20);

    /// <summary>
    /// 子女标记已处理
    /// </summary>
    Task<EmergencyCallResponse> RespondCallAsync(Guid callId, Guid userId);
}