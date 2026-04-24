using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;

namespace CareForTheOld.Services.Interfaces;

public interface IAutoRescueService
{
    /// <summary>
    /// 启动自动救援计时器：通知子女后等待延迟，超时未响应则触发邻里广播
    /// </summary>
    Task StartRescueTimerAsync(Guid elderId, Guid familyId, Guid circleId, RescueTriggerType triggerType);

    /// <summary>
    /// 检查待处理的自动救援记录（Hangfire 每分钟调用）
    /// </summary>
    Task CheckPendingRescuesAsync();

    /// <summary>
    /// 子女主动响应
    /// </summary>
    Task ChildRespondAsync(Guid recordId, Guid childId);

    /// <summary>
    /// 获取自动救援历史
    /// </summary>
    Task<List<AutoRescueRecord>> GetHistoryAsync(Guid familyId, int skip = 0, int limit = 20);
}
