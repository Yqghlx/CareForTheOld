using CareForTheOld.Common.Constants;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;

namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 自动救援服务接口：子女未响应时自动触发邻里圈广播
/// </summary>
public interface IAutoRescueService
{
    /// <summary>
    /// 启动自动救援计时器：通知子女后等待延迟，超时未响应则触发邻里广播
    /// </summary>
    Task StartRescueTimerAsync(Guid elderId, Guid familyId, Guid circleId, RescueTriggerType triggerType, CancellationToken cancellationToken = default);

    /// <summary>
    /// 检查待处理的自动救援记录（Hangfire 每分钟调用）
    /// </summary>
    Task CheckPendingRescuesAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// 子女主动响应
    /// </summary>
    Task ChildRespondAsync(Guid recordId, Guid childId, CancellationToken cancellationToken = default);

    /// <summary>
    /// 获取自动救援历史
    /// </summary>
    Task<List<AutoRescueRecord>> GetHistoryAsync(Guid familyId, int skip = AppConstants.Pagination.DefaultSkip, int limit = AppConstants.Pagination.DefaultHistoryPageSize, CancellationToken cancellationToken = default);
}
